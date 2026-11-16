require_relative "lib/onebillion/version"

Gem::Specification.new do |spec|
  spec.name = "onebillion"
  spec.version = OneBillion::VERSION
  spec.authors = ["Thadeu Esteves"]
  spec.summary = "Send transactional e-mail with 1billion, with an ActionMailer delivery method"
  spec.homepage = "https://1billion.clowk.in"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
