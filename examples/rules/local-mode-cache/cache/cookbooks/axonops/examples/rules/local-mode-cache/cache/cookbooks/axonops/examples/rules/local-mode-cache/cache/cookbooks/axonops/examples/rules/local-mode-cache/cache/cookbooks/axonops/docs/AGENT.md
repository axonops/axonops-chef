# AxonOps Agent Installation Guide

## Using the Agent Recipe

In your recipe or wrapper cookbook:

```ruby
# recipes/default.rb

# Configure agent attributes if needed
node.override['axonops']['agent']['server_url'] = 'https://agents.axonops.cloud'
node.override['axonops']['agent']['api_key'] = 'your-api-key'

# Install the agent
include_recipe 'axonops::agent'
```

## Installation Steps

1. Run `berks install` to fetch the cookbook
2. Deploy with your Chef workflow (chef-client, knife, etc.)

## Configuration Attributes

The agent recipe supports various configuration attributes. See the main cookbook documentation for a full list of available options.