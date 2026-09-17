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

Suites install Cinc (see `kitchen.yml`'s `chef_omnibus_url`), not Chef Infra —
`packages.chef.io` answers HTTP 402 for unlicensed downloads. Override the
major version with `CINC_VERSION` if needed.

To select Docker instead of Vagrant, use:
```bash
KITCHEN_DRIVER=docker bundle exec kitchen test <suite-name>
```

To add a new Kitchen suite, edit `kitchen.yml` and append to the `suites` list.
