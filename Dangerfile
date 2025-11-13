# Dangerfile for FTNetworkTracer

# Custom rules for this project

# Ensure PR has a description
if github.pr_body.length < 10
  warn("Please provide a meaningful PR description explaining what this PR does and why.")
end

# Check for test changes
has_app_changes = !git.modified_files.grep(/Sources/).empty?
has_test_changes = !git.modified_files.grep(/Tests/).empty?

if has_app_changes && !has_test_changes && !github.pr_title.downcase.include?("docs")
  warn("Consider adding tests for your changes")
end

# Check for large PRs
if git.lines_of_code > 500
  warn("This PR is quite large. Consider breaking it into smaller PRs for easier review.")
end

# Check for TODO/FIXME comments in modified files
has_todos = git.modified_files.any? do |file|
  next unless file.end_with?('.swift')
  diff = git.diff_for_file(file)
  next unless diff
  diff.patch.include?('TODO:') || diff.patch.include?('FIXME:')
end

if has_todos
  warn("This PR adds TODO or FIXME comments. Consider creating issues for them.")
end

# Ensure README is updated if public API changes
public_api_files = [
  'Sources/FTNetworkTracer/FTNetworkTracer.swift',
  'Sources/FTNetworkTracer/Analytics/AnalyticsProtocol.swift',
  'Sources/FTNetworkTracer/Logging/LoggerConfiguration.swift',
  'Sources/FTNetworkTracer/Analytics/AnalyticsConfiguration.swift'
]

has_public_api_changes = !(git.modified_files & public_api_files).empty?
has_readme_changes = git.modified_files.include?("README.md")

if has_public_api_changes && !has_readme_changes && !github.pr_title.include?("WIP")
  warn("Public API has changed. Consider updating README.md with usage examples.")
end

# Check for security-sensitive changes
security_files = git.modified_files.grep(/Analytics|Privacy|Mask|Security/)
if !security_files.empty?
  message("⚠️ This PR modifies security-sensitive files: #{security_files.join(', ')}")
  message("Please ensure SecurityTests.swift covers these changes")
end

# Celebrate achievements
if git.lines_of_code > 100 && has_test_changes
  message("🎉 Great job adding comprehensive tests!")
end

if git.modified_files.grep(/SecurityTests/).any?
  message("🔒 Security tests updated - excellent!")
end
