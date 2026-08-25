#!/usr/bin/env ruby

# Idempotently applies the shared tmuxinator conventions used by this repo.

PROJECT_DIR = File.expand_path("..", __dir__)

LAYOUTS = {
  "ai" => "tiled",
  "agents" => "tiled",
  "editor" => "main-vertical",
  "workspace" => "main-vertical",
  "upstream" => "main-vertical",
  "easy-kit" => "main-vertical",
  "pro-workspace" => "main-vertical",
  "pro-kit" => "main-vertical",
  "uh" => "main-vertical",
  "ct" => "main-vertical",
}.freeze

AGENT_RESUME = {
  "opencode" => "opencode --continue || opencode",
  "codex" => "codex resume --last || codex",
  "claude" => "claude --continue || claude",
  "agy" => "agy",
}.freeze

def portable_path(path)
  path = path.delete_prefix('"').delete_suffix('"').sub(%r{/$}, "")
  path = path.sub(%r{^/Users/[^/]+/}, "~/")
  path.start_with?("~") ? path : nil
end

def normalize_root(line)
  return line if line.include?('@settings["root"]') || line.include?("project_root")

  value = line.sub(/^root:\s*/, "").strip
  default = if (match = value.match(/@args\[0\]\s*\|\|\s*["']([^"']+)["']/))
    portable_path(match[1])
  elsif !value.include?("<%")
    portable_path(value)
  end

  return line unless default

  %(root: <%= @settings["root"] || @args[0] || File.expand_path("#{default}") %>\n)
end

def pane_name(command, index)
  case command
  when /\b(?:n?vim)\b/
    "editor"
  when /\bopencode\b/
    "opencode"
  when /\bcodex\b/
    "codex"
  when /\bclaude\b/
    "claude"
  when /\bagy\b/
    "agy"
  when /git diff/
    "diff"
  when /git status/
    "git"
  when /typecheck|test|pytest|smoke|qualif/
    "tests"
  when /\b(?:pnpm|npm|yarn|just)\b.*\b(?:dev|start|watch|serve)\b|http\.server/
    "dev"
  when /just --list/
    "commands"
  when />-/
    "task#{index}"
  else
    "shell#{index}"
  end
end

def unique_name(base, seen)
  seen[base] += 1
  seen[base] == 1 ? base : "#{base}#{seen[base]}"
end

def normalize_agents(line)
  return line if line.lstrip.start_with?("#") || line.match?(/^\s+focused_pane:/)

  AGENT_RESUME.each do |agent, resume_command|
    next if line.include?("command -v #{agent}")

    command = Regexp.escape(resume_command)
    bare = Regexp.escape(agent)
    pattern = /(?<![A-Za-z0-9_-])(?:#{command}|#{bare})(?=;|'\s*$|\s*$)/
    fallback = %({ if command -v #{agent} >/dev/null 2>&1; then #{resume_command}; else printf "%s\\n" "#{agent} is not installed"; fi; })
    line = line.gsub(pattern, fallback)
  end

  line
end

def modernize(path)
  lines = File.readlines(path)
  first_window = lines.filter_map { |line| line[/^  - ([^:]+):\s*$/, 1] }.first
  current_window = nil
  panes_indent = nil
  pane_item_indent = nil
  folded_pane_indent = nil
  pane_index = 0
  pane_names = Hash.new(0)

  lines.map! do |line|
    if folded_pane_indent && !line.strip.empty?
      indent = line[/^\s*/].length
      if indent > folded_pane_indent
        line = "  #{line}"
      else
        folded_pane_indent = nil
      end
    end

    line = "" if line.match?(/^\s+focused_pane:.*command -v/)
    line = normalize_root(line) if line.start_with?("root:")
    line = line.gsub("exec $SHELL", 'exec "$SHELL"')
    line = normalize_agents(line)
    line = line.sub(/^(\s*-\s+)vim(\s+\.)/, '\\1nvim\\2')

    if (window = line[/^  - ([^:]+):\s*$/, 1])
      current_window = window
      panes_indent = nil
      pane_item_indent = nil
      pane_index = 0
      pane_names = Hash.new(0)
    end

    if line.match?(/^\s+panes:\s*$/)
      panes_indent = line[/^\s*/].length
      pane_item_indent = nil
    elsif panes_indent
      indent = line[/^\s*/].length
      if !line.strip.empty? && indent <= panes_indent
        panes_indent = nil
        pane_item_indent = nil
      elsif (match = line.match(/^(\s*)-\s+(.+)$/))
        pane_item_indent ||= match[1].length
        if match[1].length == pane_item_indent
          command = match[2]
          unless command.match?(/^[A-Za-z0-9_-]+:\s*/)
            pane_index += 1
            name = unique_name(pane_name(command, pane_index), pane_names)
            line = "#{match[1]}- #{name}: #{command}\n"
            folded_pane_indent = pane_item_indent if command == ">-"
          end
        end
      end
    end

    if line.match?(/^\s+layout:\s+[0-9]+,/)
      layout = LAYOUTS.fetch(current_window, "even-horizontal")
      line = line.sub(/layout:.*/, "layout: #{layout}\n")
    end

    line
  end

  window_indexes = lines.each_index.select { |index| lines[index].match?(/^  - [^:]+:\s*$/) }
  window_indexes.reverse_each do |window_index|
    window_end = window_indexes.find { |index| index > window_index } || lines.length
    block = lines[window_index...window_end]
    next if block.any? { |line| line.match?(/^\s+focused_pane:/) }

    relative_panes_index = block.index { |line| line.match?(/^\s+panes:\s*$/) }
    next unless relative_panes_index

    panes_index = window_index + relative_panes_index
    panes_indent = lines[panes_index][/^\s*/]
    first_pane = lines[(panes_index + 1)...window_end].filter_map do |line|
      line[/^\s+-\s+([A-Za-z0-9_-]+):/, 1]
    end.first
    next unless first_pane

    lines.insert(panes_index, "#{panes_indent}focused_pane: #{first_pane}\n")
  end

  unless lines.any? { |line| line.start_with?("startup_window:") }
    root_index = lines.index { |line| line.start_with?("root:") }
    if root_index && first_window
      lines.insert(root_index + 1, "startup_window: #{first_window}\n")
    end
  end

  startup_index = lines.index { |line| line.start_with?("startup_window:") }
  if startup_index
    settings = []
    settings << "startup_pane: 0\n" unless lines.any? { |line| line.start_with?("startup_pane:") }
    settings << "enable_pane_titles: true\n" unless lines.any? { |line| line.start_with?("enable_pane_titles:") }
    settings << "pane_title_position: top\n" unless lines.any? { |line| line.start_with?("pane_title_position:") }
    lines.insert(startup_index + 1, *settings) unless settings.empty?
  end

  updated = lines.join
  original = File.read(path)
  return false if updated == original

  File.write(path, updated)
  true
end

changed = Dir.glob(File.join(PROJECT_DIR, "*.yml")).sort.count { |path| modernize(path) }
puts "modernized #{changed} tmuxinator configs"
