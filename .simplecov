# Test coverage settings, loaded by `require "simplecov"` at the top of spec/spec_helper.rb.
# The HTML report is written to coverage/index.html.
SimpleCov.start "rails" do # covers app/ and lib/, including files no spec loads
  # Rails boilerplate that this API-only app never uses
  add_filter %w[app/channels app/jobs/application_job.rb app/mailers/application_mailer.rb]

  enable_coverage :branch # also check both sides of every if/unless/&&/||

  # The run fails if anything is not tested. Only checked for the full suite
  # (`rspec` with no file arguments), because one spec file never covers the whole app.
  full_suite = ARGV.none? { |arg| !arg.start_with?("-") }
  minimum_coverage line: 100, branch: 100 if full_suite
end
