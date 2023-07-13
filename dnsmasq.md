# Set up dnsmasq for any .test domain

## Step 1: Install and configure Dnsmasq

Use `brew` to install `dnsmasq` by opening your preferred terminal application and run the following command:

`brew install dnsmasq`

Create a config directory for `dnsmasq`:

`mkdir -pv $(brew --prefix)/etc/`

Setup domain configurations for our `*.test` domain:

`echo 'address=/.test/127.0.0.1' >> $(brew --prefix)/etc/dnsmasq.conf`

The configuration is complete, now use the service management option of `brew` to manage the dnsmasq service: (**This will autostart the service even after reboot.**)

`sudo brew services start dnsmasq`

## Step 2: Create a dns resolver

Next create a dns resolver for the selected domain. Create a resolver directory if it doesn’t already exist:

`sudo mkdir -v /etc/resolver`

Add `dnsmasq` nameserver to resolvers:

`sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/test'`

## Step 3: Test the new dns resolver

Test if external links resolve successfully using the `ping` command below:

`ping google.com`

It still works if a reply comes from the google.com server.

Now check if `dnsmasq` handles all request on the `.test` domain:

`ping dev.test`

This should return a reply from `127.0.0.1`.
