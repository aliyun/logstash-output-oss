# Running the tests
```bash
bundle install
bundle exec rspec
```

If you want to run the integration tests against a real bucket you need to pass your Aliyun credentials to the test runner or declare it in your environment.
```bash
OSS_ENDPOINT="Aliyun OSS endpoint to connect to" OSS_ACCESS_KEY="Your access key id" OSS_SECRET_KEY="Your access secret" OSS_BUCKET="Your bucket" bundle exec rspec spec/integration --tag integration
```