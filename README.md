# upcloud-scripts
Collection of scripts you might need when working with UpCloud services.

## Scripts

### attach-floating-ip.sh

(Dependencies: curl, jq)

A script to attach your floating IP to the server. Script finds the interface where IP is configured in and contacts UpCloud API to attach it to the server.

Script can be used as it is in high-availability configurations (such as Keepalived) to automatically change it to another server if the current IP holder becomes unresponsive.

Script takes its credentials from $HOME/.upcloud-credentials . Credentials file contains them as shell variables in the following way:

```
API_USERNAME=replace_with_username
API_PASSWORD=replace_with_password
```

If credentials are for a subaccount (recommended), it should have access to all the servers that pass the floating IP between themselves (both detach and attach need access to the specific server).

Usage: `./attach-floating-ip.sh YOUR_FLOATING_IP`
