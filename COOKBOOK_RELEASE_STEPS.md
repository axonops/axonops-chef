# AxonOps Cookbook Release Steps

## Version Update and Chef Server Upload Process

### Prerequisites

1. **Install Chef Workstation or Berkshelf**
   - Berkshelf requires Ruby >= 3.0 (current system has Ruby 2.6.10)
   - Options:
     - Install Chef Workstation (includes Berkshelf): https://downloads.chef.io/tools/workstation
     - Or upgrade Ruby and install Berkshelf: `gem install berkshelf`

2. **Configure knife.rb**
   - Ensure `~/.chef/knife.rb` is configured with your Chef server details
   - See README.md for knife.rb configuration example

### Version Update Steps Completed

1. ✅ **Updated version in metadata.rb**
   - Changed from `version '0.1.0'` to `version '0.2.0'`

2. ✅ **Updated cookbook_version in example files**
   - Updated all files in `/examples/` directory to match new version

3. ✅ **Updated CHANGELOG.md**
   - Added version 0.2.0 entry with changes

### Next Steps to Complete

4. **Install dependencies locally**
   ```bash
   berks install
   ```

5. **Upload to Chef Server**
   ```bash
   # Upload all cookbooks and dependencies
   berks upload
   
   # Or upload to specific environment (excluding production)
   berks upload --except production
   ```

6. **Verify upload**
   ```bash
   # List cookbooks on Chef server
   knife cookbook list | grep axonops
   
   # Show specific cookbook details
   knife cookbook show axonops
   ```

### Alternative if Berkshelf is not available

If you cannot install Berkshelf, you can use knife directly:

```bash
# Upload cookbook with knife
knife cookbook upload axonops --cookbook-path /Users/brian.stark/work/Cust_Axonops

# Upload dependencies manually
knife cookbook upload yum --cookbook-path /path/to/cookbooks
knife cookbook upload apt --cookbook-path /path/to/cookbooks
knife cookbook upload sysctl --cookbook-path /path/to/cookbooks
```

### For Air-gapped Environments

```bash
# Package cookbooks
berks package cookbooks.tar.gz

# Transfer to Chef server and extract
tar -xzf cookbooks.tar.gz -C /path/to/chef-repo/cookbooks/

# Upload from Chef server
knife cookbook upload -a --cookbook-path /path/to/chef-repo/cookbooks/
```