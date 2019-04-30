Gem::Specification.new do |s|
  s.name          = 'logstash-output-oss'
  s.version       = '0.1.2'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'Sends Logstash events to the Aliyun Object Storage Service'
  s.description     = "This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gem-name. This gem is not a stand-alone program"
  s.authors       = ['Jinhu Wu']
  s.email         = 'jinhu.wu.nju@gmail.com'
  s.require_paths = ['lib']
  s.homepage        = "http://www.elastic.co/guide/en/logstash/current/index.html"

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency "logstash-codec-plain", "~> 3.0"
  s.add_runtime_dependency "concurrent-ruby", "~> 1.0"
  s.add_runtime_dependency "uuid", '~> 2.3', '>= 2.3.9'
  s.add_development_dependency "logstash-devutils", "~> 1.3"
  s.add_development_dependency "logstash-codec-line", "~> 3.0"
  s.platform = 'java'
  s.add_runtime_dependency 'jar-dependencies', '~> 0.3'
  s.requirements << 'jar com.aliyun.oss:aliyun-sdk-oss, 3.4.0'
end
