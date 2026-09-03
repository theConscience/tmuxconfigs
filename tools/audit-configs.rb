#!/usr/bin/env ruby

project_dir = File.expand_path("..", __dir__)
errors = []
names = Hash.new { |hash, key| hash[key] = [] }

Dir.glob(File.join(project_dir, "*.yml")).sort.each do |path|
  relative = File.basename(path)
  lines = File.readlines(path)
  text = lines.join

  static_name = text[/^name:\s+([A-Za-z0-9_-]+)\s*$/, 1]
  names[static_name] << relative if static_name

  %w[startup_window startup_pane enable_pane_titles pane_title_position].each do |setting|
    errors << "#{relative}: missing #{setting}" unless text.match?(/^#{setting}:/)
  end

  root = lines.find { |line| line.start_with?("root:") }
  unless root&.include?('@settings["root"]') || root&.include?("project_root")
    errors << "#{relative}: root must support @settings[\"root\"] or a project_root override"
  end
  if root&.include?('@args[0]') && !root.include?("File.directory?")
    errors << "#{relative}: root must ignore non-directory positional arguments"
  end

  lines.each_with_index do |line, index|
    line_number = index + 1
    next if line.lstrip.start_with?("#")

    errors << "#{relative}:#{line_number}: fixed-size layout" if line.match?(/^\s+layout:\s+[0-9]+,/)
    errors << "#{relative}:#{line_number}: machine-specific /Users path" if line.include?("/Users/")
    errors << "#{relative}:#{line_number}: quote exec \"$SHELL\"" if line.include?("exec $SHELL")

    {
      "opencode" => "opencode --continue",
      "codex" => "codex resume --last",
      "claude" => "claude --continue",
    }.each do |agent, resume|
      next unless line.match?(/\b#{agent}\b/)
      next if line.match?(/^\s+- #{agent}:\s*$/)
      next if line.match?(/^\s+focused_pane:/)
      errors << "#{relative}:#{line_number}: missing #{agent} availability check" unless line.include?("command -v #{agent}")
      errors << "#{relative}:#{line_number}: missing #{agent} resume command" unless line.include?(resume)
    end
  end

  window_indexes = lines.each_index.select { |index| lines[index].match?(/^  - [^:]+:\s*$/) }
  window_indexes.each do |window_index|
    window_end = window_indexes.find { |index| index > window_index } || lines.length
    block = lines[window_index...window_end]
    window_name = lines[window_index][/^  - ([^:]+):/, 1]
    next unless block.any? { |line| line.match?(/^\s+panes:\s*$/) }

    focused_pane = block.map { |line| line[/^\s+focused_pane:\s+([A-Za-z0-9_-]+)\s*$/, 1] }.compact.first
    errors << "#{relative}: window #{window_name} has no valid focused_pane" unless focused_pane

    panes_index = block.index { |line| line.match?(/^\s+panes:\s*$/) }
    pane_lines = block[(panes_index + 1)..]
    first_item = pane_lines.find { |line| line.match?(/^\s+-\s+/) }
    next unless first_item

    item_indent = first_item[/^\s*/].length
    pane_names = []
    pane_lines.each do |line|
      next unless line[/^\s*/].length == item_indent && line.match?(/^\s+-\s+/)
      errors << "#{relative}: window #{window_name} has an unnamed pane" unless line.match?(/^\s+-\s+[A-Za-z0-9_-]+:/)
      pane_names << line[/^\s+-\s+([A-Za-z0-9_-]+):/, 1]
    end
    if focused_pane && !pane_names.include?(focused_pane)
      errors << "#{relative}: window #{window_name} focuses missing pane #{focused_pane}"
    end
  end
end

names.each do |name, files|
  errors << "duplicate project name #{name}: #{files.join(', ')}" if files.length > 1
end

policy_path = File.join(project_dir, "tools", "root-policies.txt")
policies = {}
File.readlines(policy_path, chomp: true).each_with_index do |line, index|
  next if line.strip.empty? || line.lstrip.start_with?("#")

  project, policy, extra = line.split(/\s+/, 3)
  line_number = index + 1
  errors << "root-policies.txt:#{line_number}: expected PROJECT POLICY" unless project && policy
  errors << "root-policies.txt:#{line_number}: duplicate project #{project}" if policies.key?(project)
  unless %w[worktree-dynamic worktree-legacy reference-offline learning-recovery].include?(policy)
    errors << "root-policies.txt:#{line_number}: unknown policy #{policy}"
  end
  errors << "root-policies.txt:#{line_number}: unknown project #{project}" unless names.key?(project)
  policies[project] = policy
end

if errors.empty?
  puts "config style audit passed"
else
  warn errors.join("\n")
  exit 1
end
