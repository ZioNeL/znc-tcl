# znc-tcl

Eggdrop Tcl script for running a free ZNC service on IRC.

It handles account requests, staff approval, bindhost assignment, and talks to ZNC through `*controlpanel` and `*lastseen`.

**Version:** 5.0 (5.5)

## Features

- Public `!request` flow with staff `!confirm` / `!deny`
- Staff shortcut `!adduser` to create an account and connect it immediately
- Automatic bindhost selection from a configured IP pool (least-used, max 3 per IP)
- Optional e-mail notifications (`sendmail` or SMTP via `curl`)
- `*lastseen` listing and bindhost connection checks

## Requirements

- Eggdrop with Tcl
- ZNC with `controlpanel` and `lastseen` loaded
- A public channel for user/staff commands
- Local `sendmail` or `curl` if you want outbound mail

## Installation

```bash
cd /path/to/eggdrop/scripts
git clone https://github.com/ZioNeL/znc-tcl
```

Add this line to the Eggdrop config:

```
source scripts/znc-tcl/znc.tcl
```

Rehash the bot:

```
/msg <bot> rehash <password>
```

## Configuration

Edit `scripts/znc-tcl/znc.tcl` before going live:

| Variable | Purpose |
|---|---|
| `znchost` / `zncNonSSLPort` | ZNC listener shown to users |
| `zncnetworkname` | Network name created for each account |
| `zncircserver` / `zncircserverport` | IRC server ZNC should connect to |
| `zncChannelName` | Public command channel |
| `zncAdminMail` / `zncRequestMail` | Envelope From and staff inbox |
| `zncMailMethod` | `sendmail` or `smtp` |
| `vhost` | Outbound IPs this host can bind |
| `zncMaxUsersPerBindhost` | Maximum accounts per IP (default `3`) |

If `vhost` is empty, accounts still work, but `!request` will not auto-assign a bindhost.

## First-time setup

Run these from DCC / partyline.

Grant yourself staff flags (`+Q` covers every command, including `chpass`):

```
.chattr <your_handle> +YQ
```

Enable the script on the public channel:

```
.chanset #your_free_znc_channel +znc
```

Load the ZNC modules (as the ZNC admin user):

```
.msg *status loadmod lastseen
.msg *status loadmod controlpanel
```

Allow `*lastseen` and `*controlpanel` so Eggdrop does not ignore them:

```
.+user lastseen
.+host lastseen *lastseen!znc@znc.in
.+host lastseen *controlpanel!znc@znc.in
.chattr lastseen +f
.save
```

## Commands

The default prefix is `!` (`scriptCommandPrefix`).

### Public

| Command | Description |
|---|---|
| `!request <user> <email>` | Request a free account (staff must confirm) |
| `!status [user]` | Show pending or active status |
| `!admins` | Staff currently marked online (`+A`) |
| `!help [command]` | Command help |
| `!version` | Script version |

### Staff (`+n` / `+m` / `+Y` / `+Q`)

| Command | Description |
|---|---|
| `!confirm <user>` | Approve a pending request and e-mail the password |
| `!deny <user>` | Reject a pending request |
| `!adduser <user> <vhost>` | Create a confirmed account and connect it now |
| `!deluser <user>` | Delete a confirmed account |
| `!noidle <user>` | Delete an idle account |
| `!chemail <user> <email>` | Update the stored e-mail address |
| `!addvhost <user> <ip>` | Change bindhost and reconnect |
| `!info <user>` | Show stored account data |
| `!listunconfirmedusers` (`!luu`) | List pending accounts |
| `!online` / `!offline` `[handle]` | Mark staff online or offline |
| `!lastseen` | Query `*lastseen` |
| `!check <ip>` | Count outbound connections from a bindhost |

`!adduser` and `!addvhost` only accept a bindhost listed in `vhost`.  
`!adduser` sends the generated password to you by NOTICE. It does not e-mail the user.

`!luu` is optional. You can confirm or deny a username directly.

### Admin (`+Q`, private message only)

```
/msg <bot> chpass <user> <newpass>
```

## Notes

- After `!deluser`, `!noidle`, or `!deny`, wait a few seconds before recreating the same username with `!adduser`.
- `!request` assigns a pool IP automatically. `!confirm` then attaches the configured IRC network.

Written by NetIRC — last updated 15 August 2026.
