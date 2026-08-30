# Define these function to CLI
Rael time process conection is not required

## Reload config

```bash
kamidana reload config
```

## Launch at login

```bash
kamidana --launch-at-login <bool>
# kamidana --launch-at-login true
# kamidana --launch-at-login false
```

This command updates `global.launch_at_login` in `~/.config/kamidana/config.yaml`. When Kamidana is running, its configuration watcher synchronizes the login item after the update. Otherwise, it synchronizes the setting at the next app launch.

## Display ID

```bash
kamidana display id
```
