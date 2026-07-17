# Contributing

## Running the test suite

You can run the unit tests with:
```bash
bundle exec rspec spec/
```

To run Test Kitchen suites:
```bash
bundle exec kitchen test
```

To select Docker instead of Vagrant, use:
```bash
KITCHEN_DRIVER=docker bundle exec kitchen test <suite-name>
```

To add a new Kitchen suite, edit `kitchen.yml` and append to the `suites` list.
