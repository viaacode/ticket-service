guard :rack do
  watch 'Gemfile.lock'
  watch %r{^\w+\.ru}
  watch %r{^\w+\.rb}
  watch %r{.*\.yaml}
end

guard :rspec, cmd: 'rspec -f d 2>/dev/null' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb"  }
  watch('spec/spec_helper.rb') { "spec" }
end
