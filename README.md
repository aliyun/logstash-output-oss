# Logstash OSS Output Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation
This plugin batches and uploads logstash events into Aliyun Object Storage Service (Aliyun OSS).

First, you should have a writable bucket and OSS access permissions((Typically access_key_id and access_key_secret)).

OSS output plugin creates temporary files into the OS' temporary directory(You can set this configuration by **temporary_directory** option) before uploading them to OSS.

OSS output plugin output files have the following format
```bash
/tmp/logstash/oss/eaced620-e972-0136-2a14-02b7449ba0a9/logstash/1/ls.oss.eaced620-e972-0136-2a14-02b7449ba0a9.2018-12-24T14.27.part-0.data
```

|||
|---|---|
|/tmp/logstash/oss| OS' temporary directory specified by **temporary_directory** option |
|eaced620-e972-0136-2a14-02b7449ba0a9 | random uuid |
|logstash/1|OSS object prefix|
|ls.oss|indicate Logstash OSS output plugin|
|eaced620-e972-0136-2a14-02b7449ba0a9 | random uuid |
|2018-12-24T14.27 | represents the file created time |
|part-0|This is the nth file of this prefix|
|.data|output suffix, if you set `encoding` to gzip , it will ends with .gz, else ends with .data|


This plugin also supports crash recovery, you can set configuration **recover** to true if you want to recover from abnormal crash.

### Usage:
This is an example of logstash config:
```ruby
input {
  file {
    path => "/etc/logstash-6.5.3/sample.data"
    codec => json {
      charset => "UTF-8"
    }
  }
}

output {
  oss {
    "endpoint" => "OSS endpoint to connect to"              (required)
    "bucket" => "Your bucket name"                          (required)
    "access_key_id" => "Your access key id"                 (required)
    "access_key_secret" => "Your access secret key"         (required)
    "prefix" => "logstash/%{index}"                         (optional, default = "")
    "recover" => true                                       (optional, default = true)
    "rotation_strategy" => "size_and_time"                  (optional, default = "size_and_time")
    "time_rotate" => 15                                     (optional, default = 15) - Minutes
    "size_rotate" => 31457280                               (optional, default = 31457280) - Bytes
    "encoding" => "gzip"                                    (optional, default = "none")
    "additional_oss_settings" => {
      "max_connections_to_oss" => 1024                      (optional, default = 1024)
      "secure_connection_enabled" => false                  (optional, default = false)
    }
    codec => json {
      charset => "UTF-8"
    }
  }
}
```

### Logstash OSS Output Configuration Options
This plugin supports the following configuration options

|Configuration|Type|Required|Comments|
|:---:|:---:|:---:|:---|
|endpoint|string|Yes|OSS endpoint to connect|
|bucket|string|Yes|Your OSS bucket name|
|access_key_id|string|Yes|Your access key id|
|access_key_secret|string|Yes|Your access secret key|
|prefix|string|No|Prefix that added to the generated file name(WARNING: this option supports string interpolation, so it may create a lot of temporary local files)|
|additional_oss_settings|hash|No|Additional oss client configurations, valid keys are: `server_side_encryption_algorithm`, `secure_connection_enabled` and `max_connections_to_oss`|
|temporary_directory|string|No|Temporary directory that used to cache events before uploading to OSS, default is /{OS' tmp dir}/logstash/oss|
|rotation_strategy|string|No|File rotation strategy. Options are `size`, `time` and `size_and_time`|
|size_rotate|number|No|Rotate this file if its size greater than or equal to `size_rotate`(depends on `rotation_strategy`)|
|time_rotate|number|No|Rotate this file if its life time greater than or equal to `time_rotate`(depends on `rotation_strategy`)|
|upload_workers_count|number|No|Concurrent number of upload threads|
|upload_queue_size|number|No|Upload queue size|
|encoding|string|No|Support plain and gzip compression before uploading files to OSS. Options are `gzip` and `none`|

## Need Help?

Need help? Try #logstash on freenode IRC or the https://discuss.elastic.co/c/logstash discussion forum.

## Deployment
This plugin has been submitted to [RubyGems.org](https://rubygems.org/gems/logstash-output-oss), and Logstash uses RubyGems.org as its repository for all plugin artifacts.
So you can simply install this plugin in your Logstash home directory by:

```bash
./bin/logstash-plugin install logstash-output-oss
```
And you will get following message:

```bash
Validating logstash-output-oss
Installing logstash-output-oss
      com.aliyun.oss:aliyun-sdk-oss:3.4.0:compile
Installation successful
```

You can also list plugins by:
```bash
./bin/logstash-plugin list --verbose logstash-output-oss

logstash-output-oss (0.1.1)
```

## Developing

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Install dependencies
```sh
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run tests

```sh
bundle exec rspec
```

### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in an installed Logstash

you can build the gem and install it using:

- Build your plugin gem

```sh
gem build logstash-output-oss.gemspec
```

- Install the plugin from the Logstash home

```sh
bin/logstash-plugin install /path/to/logstash-output-oss-0.1.1-java.gem
```

- Start Logstash and proceed to test the plugin

```bash
./bin/logstash -f config/logstash-sample.conf
```

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elastic/logstash/blob/master/CONTRIBUTING.md) file.
