# =============================================================================
#  Free ZNC management script for Eggdrop
#  -----------------------------------------------------------------------------
#  Written by NetIRC IRC Network   -   server: irc.netirc.eu  port: 6667
#  Version 5.0
#
#  Account requests, staff moderation tools and ZNC *controlpanel integration.
# =============================================================================
#
#  IRC COMMAND REFERENCE  (prefix is configurable via scriptCommandPrefix, "!")
#  -----------------------------------------------------------------------------
#   Public (everyone):
#     !request <user> <email>       Request a FREE ZNC account
#     !status [username]            Check request status (active / pending)
#     !admins                       Show which admins are currently online (+A)
#     !help [command]               Full help / per-command help
#     !version                      Script version info
#
#   Staff  (+n / +m / +Y / +Q):
#     !confirm <user>               Approve a pending request
#     !deny <user>                  Reject a pending request
#     !deluser <user>               Delete a confirmed account
#     !noidle <user>                Delete an idle account (>15 days)
#     !chemail <user> <email>       Update a user's e-mail address
#     !addvhost <user> <ip>         Assign a bindhost and trigger reconnect
#     !info <user>                  Show stored data for a user
#     !listunconfirmedusers (!luu)  List users waiting for approval
#     !online / !offline <handle>   Mark a staff handle online/offline (+A)
#     !lastseen                     Query the ZNC *lastseen module
#     !check <ip>                   Audit outbound connections per bindhost
#
#   Admin (+Q only, PRIVATE MESSAGE to the bot):
#     /msg <bot> chpass <user> <newpass>   Reset a user's ZNC password
#
#  CONFIGURATION GUIDE   (edit the sections below before production use)
#  -----------------------------------------------------------------------------
#   --- Channel and Eggdrop access ---
#     * zncChannelName: channel where users run !request / staff commands.
#     * After load:  .chanset #yourchan +znc   (enables public commands).
#     * Staff handles need a global flag: +Q, +Y, +n, or +m. chpass requires +Q.
#
#   --- ZNC connection (shown to users and sent to controlpanel) ---
#     * znchost, zncNonSSLPort:        listener users connect to.
#     * zncnetworkname,
#       zncircserver, zncircserverport: IRC network attached to new users.
#     * zncprefix:                     ZNC PRIVMSG target prefix (usually *).
#
#   --- Outbound e-mail (pick ONE method) ---
#     [A] sendmail  (local MTA: postfix, exim, nullmailer, ...)
#         zncMailMethod sendmail
#         sendmailPath   path to sendmail binary (often /usr/sbin/sendmail)
#         -> No SMTP credentials stored in the script; the local MTA relays.
#
#     [B] SMTP via curl (remote relay: ISP, Mailgun, Google Workspace, ...)
#         zncMailMethod smtp
#         zncSmtpHost, zncSmtpPort, zncSmtpUser, zncSmtpPass
#         zncSmtpTls  = none | starttls (port 587) | ssl (port 465)
#         zncCurlPath   path to curl if not in $PATH
#         -> Eggdrop has no built-in SMTP AUTH; curl does the TLS handshake.
#
#     Addresses used by the templates:
#       zncAdminMail    Envelope From / support footer
#       zncRequestMail  Staff inbox for requests, confirmations, audit copies
#
#   --- Runtime toggles (see ## Toggles) ---
#     zncInterStepDelay  Seconds between queued ZNC steps (0 = next timer tick).
#     zncMailDefer       Queue mail on disk then send FIFO (safer under load).
#     zncUsePutNow       Use putnow for PRIVMSG to ZNC services (bypass queue).
#
# =============================================================================

## Meta
set scriptname "Free ZNC management script for Eggdrop"
set scriptAuthor "NetIRC IRC Network"
set scriptServer "irc.netirc.eu"
set scriptServerPort "6667"
set scriptNetwork "NetIRC IRC Network"
set scriptUpdater "NetIRC IRC Network"
set scriptUpdaterMail "admin@netirc.eu"
set scriptversion "5.0"
set scriptversionUpdated "5.4"
set scriptdebug 0
set scriptUseBigHeader 1

proc znc:version:pretty {} {
    global scriptversion scriptversionUpdated
    if {![info exists scriptversionUpdated] || $scriptversionUpdated eq $scriptversion} {
        return $scriptversion
    }
    return "$scriptversion ($scriptversionUpdated)"
}

putlog "$scriptname loading (v[znc:version:pretty])..."

## Toggles
# zncWarnNonZncChannel   : NOTICE if someone uses a command on a chan without +znc.
# zncShowQuickAck        : immediate NOTICE on !request before the ZNC chain runs.
# zncInterStepDelay      : seconds between queued ZNC steps (0 = next timer tick).
# zncMailDefer           : queue mails on disk then send in FIFO (safer under load).
# zncUsePutNow           : use putnow for PRIVMSG to ZNC services.
# zncRateMaxPerHour      : max !request accepted from the same IRC host per hour.
# zncRateWindowSec       : sliding window for rate limiting (seconds).
# zncRollbackTimeoutSec  : if *controlpanel doesn't confirm AddUser within this
#                          many seconds, assume success (no active rollback).
# zncConfirmWaitRetrySec : when !confirm runs while !request is still provisioning,
#                          wait this many seconds before retrying AddServer.
# zncConfirmWaitMaxRetries: max retries before forcing AddServer anyway.
# zncRevealPassOnConfirm : 1 = show the password in the staff NOTICE on confirm,
#                          0 = hide it (password only goes by e-mail + bot log).
#                          Recommended: 0.
# zncAuditFile           : path to the audit log. Empty disables auditing.
set zncWarnNonZncChannel  1
set zncShowQuickAck       1
set zncInterStepDelay     0
set zncMailDefer          1
set zncUsePutNow          1
set zncRateMaxPerHour     10
set zncRateWindowSec      3600
set zncRollbackTimeoutSec 20
set zncConfirmWaitRetrySec 1
set zncConfirmWaitMaxRetries 20
set zncRevealPassOnConfirm 1
set zncAuditFile "logs/znc-audit.log"

# zncFmt: every user-facing NOTICE template lives here so wording and style
# can be reviewed in one place. Each value may contain printf-style %s tokens;
# they are filled in by znc:fmt at call time.
array set zncFmt {
    request_quick       {Hello %s, processing your account request for "%s". This can take a few seconds, please wait...}
    request_done        {Hello %s, your request for "%s" has been received. A staff member will review it and you will get an e-mail with the credentials once approved.}
    request_syntax      {Syntax: %srequest <username> <email>}
    username_taken      {That username is already in use on this bot - please pick a different one.}
    request_zncfail     {Your Eggdrop account was saved but the ZNC setup failed. Staff has been notified (see bot log).}
    wrongchan           {ZNC commands are disabled on this channel. Staff must enable them with: .chanset %s +znc (expected channel: %s)}
    confirm_syntax      {Syntax: %sconfirm <username>}
    confirm_wait        {Confirming "%s", please wait (ZNC setup may still be running from a recent !request)...}
    confirm_ok          {"%s" has been confirmed. Login credentials have been e-mailed to the requester.}
    confirm_ok_reveal   {"%s" has been confirmed. Connect to ZNC using username "%s" and server password: %s}
    rate_limited        {Too many requests from your host (max %s per %s seconds). Please wait a bit and try again.}
    info_unknown        {Unknown user "%s".}
    status_unknown      {No account found for "%s". Use %srequest to request one.}
    status_pending      {Your account "%s" is PENDING staff approval. You will receive an e-mail once confirmed.}
    status_active       {Your account "%s" is ACTIVE. Host: %s, Port: %s.}
    confirm_already     {"%s" is already confirmed.}
    confirm_none        {No pending request for user "%s".}
    join1               {Welcome to %s on %s - type %srequest to request a free ZNC account.}
    join2               {Use %1$sadmins to see if staff are currently online, or %1$shelp for the full command list.}
    deny_wait           {Denying request for "%s", please wait...}
    deluser_wait        {Deleting account "%s", please wait...}
    noidle_wait         {Removing idle account "%s", please wait...}
    addvhost_wait       {Applying bindhost change for "%s", please wait...}
    bindhost_pool_full  {All outbound IPs are currently at capacity (max %s accounts per IP). Your ZNC account was created without a bindhost; staff can assign one manually with: %saddvhost <user> <ip>}
    chemail_busy        {Updating e-mail address for "%s"...}
    chpass_busy         {Updating password for "%s"...}
    lastseen_busy       {Querying *lastseen; NOTICEs start a few seconds after ZNC stops sending lines...}
    lastseen_wait       {Another lastseen query is already running. Try again in a few seconds.}
    listunconf_busy     {Looking up pending (unconfirmed) accounts...}
    online_busy         {Marking "%s" as online...}
    offline_busy        {Marking "%s" as offline...}
    admins_busy         {Looking up online admins...}
}

proc znc:fmt {id args} {
    global zncFmt
    return [format $zncFmt($id) {*}$args]
}

## Security / audit / rate-limit helpers
## These live at the top because they are called from request / staff flows.

# Reject any argument that could be used to inject protocol commands either
# into the IRC stream (CR / LF) or into the ZNC command channel (NUL, other
# C0 controls). Also reject empty strings and strings longer than 256 chars.
# Returns 1 if the argument is safe to forward, 0 otherwise.
proc znc:safeArg {s} {
    if {$s eq ""} { return 0 }
    if {[string length $s] > 256} { return 0 }
    # 0x00-0x08, 0x0A-0x1F, 0x7F : control chars minus TAB. NEVER allow CR/LF.
    if {[regexp {[\x00-\x08\x0A-\x1F\x7F]} $s]} { return 0 }
    return 1
}

# Convenience: check multiple args at once. Returns 1 only if all pass.
proc znc:safeArgs {args} {
    foreach a $args { if {![znc:safeArg $a]} { return 0 } }
    return 1
}

# Append a structured line to the audit log. Failures are non-fatal and
# reported once to the bot log so the main flow keeps working even if the
# logs directory is missing or read-only.
#   operator : the Eggdrop handle (or IRC nick) that triggered the action.
#   action   : short verb, e.g. request, confirm, deny, deluser, chpass...
#   target   : the target ZNC user / IP / ...
#   note     : optional free-form context (reason, error message, ...).
proc znc:audit {operator action target {note ""}} {
    global zncAuditFile scriptname
    if {![info exists zncAuditFile] || $zncAuditFile eq ""} { return }
    if {[catch {
        set dir [file dirname $zncAuditFile]
        if {$dir ne "" && $dir ne "." && ![file exists $dir]} {
            file mkdir $dir
        }
        set fd [open $zncAuditFile a]
        fconfigure $fd -encoding utf-8
        set ts [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]
        puts $fd [format "%s | %-10s | op=%s | target=%s | %s" \
                     $ts $action $operator $target $note]
        close $fd
    } err]} {
        putlog "$scriptname: audit log write failed: $err"
    }
}

# Rate limiting for !request. We key on IRC host (the "user@host" portion of
# the sender) so that someone switching nicks on the same host still counts
# towards the same quota. A stale entry older than zncRateWindowSec is dropped.
array set zncRateRequest {}
array set zncProvisioning {}

proc znc:rate:clean {key} {
    global zncRateRequest zncRateWindowSec
    set now [clock seconds]
    set kept {}
    if {[info exists zncRateRequest($key)]} {
        foreach ts $zncRateRequest($key) {
            if {$now - $ts < $zncRateWindowSec} { lappend kept $ts }
        }
    }
    if {[llength $kept] == 0} {
        catch { unset zncRateRequest($key) }
    } else {
        set zncRateRequest($key) $kept
    }
    return [llength $kept]
}

proc znc:rate:allowed {host} {
    global zncRateMaxPerHour
    set key [string tolower $host]
    set n [znc:rate:clean $key]
    return [expr {$n < $zncRateMaxPerHour}]
}

proc znc:rate:record {host} {
    global zncRateRequest
    set key [string tolower $host]
    znc:rate:clean $key
    lappend zncRateRequest($key) [clock seconds]
}

# Track usernames whose initial !request provisioning is still in flight.
# !confirm can race this chain and attempt AddServer before AddNetwork exists.
proc znc:provisioning:mark {user} {
    global zncProvisioning
    set key [string tolower [string trim $user]]
    if {$key eq ""} { return }
    set zncProvisioning($key) [clock seconds]
}

proc znc:provisioning:clear {user} {
    global zncProvisioning
    set key [string tolower [string trim $user]]
    if {$key eq ""} { return }
    catch { unset zncProvisioning($key) }
}

proc znc:provisioning:active {user} {
    global zncProvisioning
    set key [string tolower [string trim $user]]
    if {$key eq ""} { return 0 }
    return [info exists zncProvisioning($key)]
}

## Network, ZNC, and mail routing
set scriptCommandPrefix "!"

# Mail: set zncMailMethod to  sendmail  or  smtp  (see header). Remaining vars apply only to that mode.
set sendmailPath "/usr/sbin/sendmail"
set zncMailMethod "sendmail"
set zncSmtpHost ""
set zncSmtpPort "587"
set zncSmtpUser ""
set zncSmtpPass ""
set zncSmtpTls "starttls"
set zncCurlPath "/usr/bin/curl"

# ZNC pseudo-client prefix (*controlpanel, *lastseen, ...); match ZNC StatusPrefix.
set zncprefix "*"

set zncLastseenIdleSec 12
set zncLastseenNoticeDelay 0.45
set zncLastseenFailsafeSec 180
set zncLastseenRxIdleSec 3
# set zncLastseenDebug 1

# Bouncer hostname and port (user-facing strings and mail bodies).
set znchost "chat.netirc.eu"
set zncNonSSLPort "2020"

# Envelope / template addresses: From (zncAdminMail), staff request inbox (zncRequestMail).
set zncAdminMail "admin@netirc.eu"
set zncRequestMail "request@netirc.eu"

# Logical network name and IRC server ZNC should use for new accounts.
set zncnetworkname "NetIRC"
set zncircserver "chat.netirc.eu"
set zncircserverport "6667"

# Public channel where +znc is enabled for this script (see .chanset).
set zncChannelName "#FreeZNC"

# Modules loaded for each new user / network (ZNC module names).
set zncDefaultUserModules {controlpanel}
set zncDefaultNetworkModules {}

# Random password complexity for new accounts (see znc:randpw).
set zncPasswordSecurityLevel 3
set zncPasswordLength 16

setudef flag znc

# Bindhost pool: real outbound IPs on this host. zncMaxUsersPerBindhost caps users per IP (XTRA bindhost).
set zncMaxUsersPerBindhost 3

set vhost {
"192.168.1.101"
"192.168.1.102"
"192.168.1.103"
"192.168.1.104"
"192.168.1.105"
"192.168.1.106"
"192.168.1.107"
"192.168.1.108"
"192.168.1.109"
"192.168.1.111"
"192.168.1.112"
"192.168.1.113"
"192.168.1.114"
"192.168.1.115"
"192.168.1.116"
"192.168.1.117"
"192.168.1.118"
"192.168.1.119"
"192.168.1.120"
"192.168.1.121"
"192.168.1.122"
"192.168.1.123"
"192.168.1.124"
"192.168.1.125"
"192.168.1.126"
"192.168.1.127"
"192.168.1.128"
"192.168.1.129"
"192.168.1.130"
"192.168.1.131"
"192.168.1.132"
"192.168.1.133"
"192.168.1.134"
"192.168.1.135"
"192.168.1.136"
"192.168.1.137"
"192.168.1.138"
"192.168.1.139"
"192.168.1.140"
"192.168.1.141"
"192.168.1.142"
"192.168.1.143"
"192.168.1.144"
"192.168.1.145"
"192.168.1.146"
"192.168.1.147"
"192.168.1.148"
"192.168.1.149"
"192.168.1.150"
"192.168.1.151"
"192.168.1.152"
"192.168.1.153"
"192.168.1.154"
"192.168.1.155"
}

## Access control

proc znc:notice {target text} {
    putquick "NOTICE $target :$text"
}

proc znc:next {cmd} {
    global zncInterStepDelay
    if {![info exists zncInterStepDelay]} { set zncInterStepDelay 0 }
    utimer $zncInterStepDelay $cmd
}

proc znc:pub:channelOk {nick chan} {
    global zncWarnNonZncChannel zncChannelName
    if {[catch {validchan $chan} ok] || !$ok} { return 0 }
    if {[catch {set has [channel get $chan znc]}]} { set has 0 }
    if {!$has} {
        if {$zncWarnNonZncChannel} {
            znc:notice $nick [znc:fmt wrongchan $chan $zncChannelName]
        }
        return 0
    }
    return 1
}

proc znc:staff:ok {handle} {
    if {![validuser $handle]} { return 0 }
    if {[matchattr $handle Q]} { return 1 }
    if {[matchattr $handle n]} { return 1 }
    if {[matchattr $handle m]} { return 1 }
    if {[matchattr $handle Y]} { return 1 }
    return 0
}

proc znc:mustStaff {nick handle} {
    if {[znc:staff:ok $handle]} { return 1 }
    znc:notice $nick "Access denied - you need bot flags +n, +m, +Y, or +Q."
    return 0
}

proc znc:mustAdmin {nick handle} {
    if {[validuser $handle] && [matchattr $handle Q]} { return 1 }
    znc:notice $nick "Access denied - you need bot flag +Q for this command."
    return 0
}

## ZNC control (PRIVMSG to controlpanel, lastseen, blockuser)

proc znc:irc:out {text} {
    global zncUsePutNow
    if {![info exists zncUsePutNow]} { set zncUsePutNow 1 }
    if {$zncUsePutNow && [llength [info commands putnow]]} {
        putnow $text
    } else {
        putquick $text
    }
}

proc znc:cp {cmd} {
    global zncprefix
    znc:irc:out "PRIVMSG ${zncprefix}controlpanel :$cmd"
}

proc znc:lastseen:send {cmd} {
    global zncprefix
    znc:irc:out "PRIVMSG ${zncprefix}lastseen :$cmd"
}

proc znc:lastseen:session_busy {} {
    global znc_lastseen_pending znc_lastseen_sendq znc_lastseen_drain_utimer \
        znc_lastseen_rx_buf znc_lastseen_rx_idle_timer
    if {[info exists znc_lastseen_pending] && $znc_lastseen_pending ne ""} { return 1 }
    if {[info exists znc_lastseen_rx_idle_timer]} { return 1 }
    if {[info exists znc_lastseen_rx_buf] && [llength $znc_lastseen_rx_buf] > 0} { return 1 }
    if {[info exists znc_lastseen_sendq] && [llength $znc_lastseen_sendq] > 0} { return 1 }
    if {[info exists znc_lastseen_drain_utimer]} { return 1 }
    return 0
}

proc znc:lastseen:enqueue_notice {dest line} {
    global znc_lastseen_sendq znc_lastseen_drain_utimer
    if {![info exists znc_lastseen_sendq]} { set znc_lastseen_sendq {} }
    lappend znc_lastseen_sendq [list $dest $line]
    if {![info exists znc_lastseen_drain_utimer]} {
        set znc_lastseen_drain_utimer [utimer 0 [list znc:lastseen:drain_notice_queue]]
    }
}

proc znc:lastseen:drain_notice_queue {} {
    global znc_lastseen_sendq znc_lastseen_drain_utimer zncLastseenNoticeDelay
    unset -nocomplain znc_lastseen_drain_utimer
    if {![info exists zncLastseenNoticeDelay] || $zncLastseenNoticeDelay < 0.1} {
        set zncLastseenNoticeDelay 0.45
    }
    if {![info exists znc_lastseen_sendq] || [llength $znc_lastseen_sendq] == 0} {
        return
    }
    set pair [lindex $znc_lastseen_sendq 0]
    set znc_lastseen_sendq [lrange $znc_lastseen_sendq 1 end]
    set dest [lindex $pair 0]
    set txt [lindex $pair 1]
    putserv "NOTICE $dest :\[\002lastseen\002\] $txt"
    if {[llength $znc_lastseen_sendq] > 0} {
        set znc_lastseen_drain_utimer [utimer $zncLastseenNoticeDelay \
            [list znc:lastseen:drain_notice_queue]]
    }
}

proc znc:lastseen:clear_session {{force 0}} {
    global znc_lastseen_pending znc_lastseen_clear_timer znc_lastseen_failsafe_timer \
        znc_lastseen_line_count znc_lastseen_sendq znc_lastseen_drain_utimer \
        znc_lastseen_rx_buf znc_lastseen_rx_idle_timer scriptname
    if {$force} {
        if {[info exists znc_lastseen_clear_timer]} {
            catch {killutimer $znc_lastseen_clear_timer}
        }
        if {[info exists znc_lastseen_failsafe_timer]} {
            catch {killutimer $znc_lastseen_failsafe_timer}
        }
        if {[info exists znc_lastseen_rx_idle_timer]} {
            catch {killutimer $znc_lastseen_rx_idle_timer}
        }
        if {[info exists znc_lastseen_drain_utimer]} {
            catch {killutimer $znc_lastseen_drain_utimer}
        }
        if {[info exists znc_lastseen_sendq] && [llength $znc_lastseen_sendq] > 0} {
            putlog "$scriptname: lastseen failsafe dropped [llength $znc_lastseen_sendq] queued NOTICE(s)."
        }
        unset -nocomplain znc_lastseen_pending znc_lastseen_clear_timer znc_lastseen_failsafe_timer \
            znc_lastseen_line_count znc_lastseen_sendq znc_lastseen_drain_utimer \
            znc_lastseen_rx_buf znc_lastseen_rx_idle_timer
        return
    }
    if {[info exists znc_lastseen_sendq] && [llength $znc_lastseen_sendq] > 0} {
        set znc_lastseen_clear_timer [utimer 1 [list znc:lastseen:clear_session 0]]
        return
    }
    if {[info exists znc_lastseen_drain_utimer]} {
        set znc_lastseen_clear_timer [utimer 1 [list znc:lastseen:clear_session 0]]
        return
    }
    if {[info exists znc_lastseen_clear_timer]} {
        catch {killutimer $znc_lastseen_clear_timer}
    }
    if {[info exists znc_lastseen_failsafe_timer]} {
        catch {killutimer $znc_lastseen_failsafe_timer}
    }
    unset -nocomplain znc_lastseen_pending znc_lastseen_clear_timer znc_lastseen_failsafe_timer \
        znc_lastseen_line_count znc_lastseen_sendq znc_lastseen_drain_utimer \
        znc_lastseen_rx_buf znc_lastseen_rx_idle_timer
}

proc znc:lastseen:flush_rx {} {
    global znc_lastseen_rx_buf znc_lastseen_rx_idle_timer znc_lastseen_pending \
        znc_lastseen_clear_timer zncLastseenIdleSec scriptname zncLastseenDebug
    unset -nocomplain znc_lastseen_rx_idle_timer
    if {![info exists znc_lastseen_rx_buf]} { set znc_lastseen_rx_buf {} }
    if {[llength $znc_lastseen_rx_buf] == 0} { return }
    if {[info exists zncLastseenDebug] && $zncLastseenDebug} {
        putlog "$scriptname: lastseen flush [llength $znc_lastseen_rx_buf] line(s) to NOTICE queue."
    }
    set buf $znc_lastseen_rx_buf
    set znc_lastseen_rx_buf {}
    foreach line $buf {
        if {[info exists znc_lastseen_pending] && $znc_lastseen_pending ne ""} {
            znc:lastseen:enqueue_notice $znc_lastseen_pending $line
        }
        foreach u [userlist A] {
            set n2 [hand2nick $u]
            if {$n2 eq ""} { continue }
            if {[info exists znc_lastseen_pending] && $znc_lastseen_pending ne ""} {
                if {[string equal -nocase $n2 $znc_lastseen_pending]} { continue }
            }
            znc:lastseen:enqueue_notice $n2 $line
        }
    }
    if {[info exists znc_lastseen_clear_timer]} {
        catch {killutimer $znc_lastseen_clear_timer}
    }
    if {![info exists zncLastseenIdleSec]} { set zncLastseenIdleSec 12 }
    set znc_lastseen_clear_timer [utimer $zncLastseenIdleSec [list znc:lastseen:clear_session 0]]
}

proc znc:block {u} {
    global zncprefix
    znc:irc:out "PRIVMSG ${zncprefix}blockuser :block $u"
}

proc znc:unblock {u} {
    global zncprefix
    znc:irc:out "PRIVMSG ${zncprefix}blockuser :unblock $u"
}

## Mail transport

proc znc:mail:unlink {path} { catch {file delete -force $path} }

# RFC822 date in the form required by mail servers (e.g. "Mon, 20 Apr 2026 14:32:10 +0200")
proc znc:mail:rfc822_date {} {
    return [clock format [clock seconds] -format {%a, %d %b %Y %H:%M:%S %z}]
}

# Generate a reasonably unique Message-ID using pid + clock + random + host.
proc znc:mail:message_id {} {
    global znchost
    set host $znchost
    if {$host eq ""} { set host "localhost" }
    set rnd [format %08x [expr {int(rand()*0x7fffffff)}]]
    return "<[pid].[clock milliseconds].$rnd@$host>"
}

# Build a complete RFC822 message with proper headers, CRLF line endings, and UTF-8 body.
# Empty Cc is omitted (some MTAs dislike empty Cc:).
proc znc:mail:build_rfc822 {from toList subject body cc} {
    global scriptname
    set msg ""
    append msg "Date: [znc:mail:rfc822_date]\r\n"
    append msg "From: $from\r\n"
    append msg "To: [join $toList {, }]\r\n"
    set ccClean {}
    foreach addr $cc { if {$addr ne ""} { lappend ccClean $addr } }
    if {[llength $ccClean] > 0} {
        append msg "Cc: [join $ccClean {, }]\r\n"
    }
    append msg "Subject: $subject\r\n"
    append msg "Message-ID: [znc:mail:message_id]\r\n"
    append msg "MIME-Version: 1.0\r\n"
    append msg "Content-Type: text/plain; charset=UTF-8\r\n"
    append msg "Content-Transfer-Encoding: 8bit\r\n"
    append msg "X-Mailer: $scriptname v[znc:version:pretty] (Eggdrop Tcl)\r\n"
    append msg "Auto-Submitted: auto-generated\r\n"
    append msg "\r\n"
    # Normalize LF to CRLF in the body.
    set bodyCRLF [string map {"\r\n" "\r\n" "\n" "\r\n"} $body]
    append msg $bodyCRLF
    return $msg
}

proc znc:mail:send:sendmail_file {tmpPath} {
    global sendmailPath scriptname
    if {[catch {
        set nt [file nativename $tmpPath]
        set sm [file nativename $sendmailPath]
        exec /bin/sh -c [format {(%s -oi -t < '%s' && rm -f '%s') >/dev/null 2>&1 &} $sm $nt $nt]
    } err]} {
        catch {file delete -force $tmpPath}
        putlog "$scriptname: mail send (sendmail exec): $err"
    }
}

proc znc:mail:send:smtp_file {tmpPath from toList cc} {
    global zncSmtpHost zncSmtpPort zncSmtpUser zncSmtpPass zncSmtpTls zncCurlPath scriptname
    if {$zncSmtpHost eq ""} {
        putlog "$scriptname: zncMailMethod is smtp but zncSmtpHost is empty - set host/port or use sendmail."
        catch {file delete -force $tmpPath}
        return
    }
    if {[catch {
        set curl $zncCurlPath
        if {$curl ne "" && ![file exists $curl]} {
            set curl curl
        }
        if {$curl eq ""} { set curl curl }
        set cmd [list $curl -sS --mail-from $from]
        foreach addr $toList { lappend cmd --mail-rcpt $addr }
        foreach addr $cc {
            if {$addr ne ""} { lappend cmd --mail-rcpt $addr }
        }
        if {$zncSmtpUser ne ""} {
            lappend cmd --user ${zncSmtpUser}:$zncSmtpPass
        }
        if {$zncSmtpTls eq "starttls"} {
            lappend cmd --ssl-reqd
        }
        lappend cmd --upload-file $tmpPath
        if {$zncSmtpTls eq "ssl"} {
            lappend cmd "smtps://${zncSmtpHost}:${zncSmtpPort}"
        } else {
            lappend cmd "smtp://${zncSmtpHost}:${zncSmtpPort}"
        }
        exec {*}$cmd &
        utimer 10 [list znc:mail:unlink $tmpPath]
    } err]} {
        catch {file delete -force $tmpPath}
        putlog "$scriptname: mail send (SMTP/curl) failed: $err"
    }
}

proc znc:mail:send:sendmail {from toList subject body cc} {
    global scriptname
    set blob [znc:mail:build_rfc822 $from $toList $subject $body $cc]
    set tmp [file join /tmp zncmail_[pid]_[clock milliseconds].eml]
    if {[catch {
        set fd [open $tmp w]
        puts -nonewline $fd $blob
        close $fd
    } err]} {
        putlog "$scriptname: mail send (sendmail write): $err"
        return
    }
    znc:mail:send:sendmail_file $tmp
}

proc znc:mail:send:smtp {from toList subject body cc} {
    global scriptname
    set blob [znc:mail:build_rfc822 $from $toList $subject $body $cc]
    set tmp [file join /tmp zncmail_[pid]_[clock milliseconds].eml]
    if {[catch {
        set fd [open $tmp w]
        puts -nonewline $fd $blob
        close $fd
    } err]} {
        putlog "$scriptname: mail send (smtp write): $err"
        return
    }
    znc:mail:send:smtp_file $tmp $from $toList $cc
}

proc znc:mail:send:dispatch {from toList subject body cc} {
    global zncMailMethod
    if {![info exists zncMailMethod]} { set zncMailMethod sendmail }
    if {$zncMailMethod eq "smtp"} {
        znc:mail:send:smtp $from $toList $subject $body $cc
    } else {
        znc:mail:send:sendmail $from $toList $subject $body $cc
    }
}

proc znc:mail:fifo_step_exec {tmp from toList cc} {
    global zncMailMethod scriptname
    if {[catch {
        if {![info exists zncMailMethod]} { set zncMailMethod sendmail }
        if {$zncMailMethod eq "smtp"} {
            znc:mail:send:smtp_file $tmp $from $toList $cc
        } else {
            znc:mail:send:sendmail_file $tmp
        }
    } err]} {
        putlog "$scriptname: znc:mail:fifo_step_exec: $err"
        catch {file delete -force $tmp}
    }
    utimer 0 znc:mail:fifo_step_write
}

proc znc:mail:fifo_step_write {} {
    global zncMailFIFO zncMailFIFOBusy scriptname
    if {![info exists zncMailFIFO] || [llength $zncMailFIFO] == 0} {
        set zncMailFIFOBusy 0
        return
    }
    foreach {from toList subject body cc} [lindex $zncMailFIFO 0] break
    if {[catch {
        set blob [znc:mail:build_rfc822 $from $toList $subject $body $cc]
        set tmp [file join /tmp zncmail_[pid]_[clock milliseconds].eml]
        set fd [open $tmp w]
        puts -nonewline $fd $blob
        close $fd
    } err]} {
        putlog "$scriptname: znc:mail (fifo write): $err"
        set zncMailFIFO [lrange $zncMailFIFO 1 end]
        utimer 0 znc:mail:fifo_step_write
        return
    }
    set zncMailFIFO [lrange $zncMailFIFO 1 end]
    utimer 0 [list znc:mail:fifo_step_exec $tmp $from $toList $cc]
}

proc znc:mail:send {from toList subject body {cc ""}} {
    global zncMailDefer zncMailFIFO zncMailFIFOBusy
    if {![info exists zncMailDefer]} { set zncMailDefer 1 }
    if {!$zncMailDefer} {
        znc:mail:send:dispatch $from $toList $subject $body $cc
        return
    }
    if {![info exists zncMailFIFO]} { set zncMailFIFO {} }
    if {![info exists zncMailFIFOBusy]} { set zncMailFIFOBusy 0 }
    lappend zncMailFIFO [list $from $toList $subject $body $cc]
    if {!$zncMailFIFOBusy} {
        set zncMailFIFOBusy 1
        utimer 0 znc:mail:fifo_step_write
    }
}

# Generate a random password of the requested length.
#   level 1 -> digits only
#   level 2 -> digits + lowercase letters
#   level 3 -> digits + mixed-case letters   (default, recommended)
#   level 4 -> digits + mixed-case + symbols (safe for ZNC server password)
#
# Prefers /dev/urandom (cryptographically secure on Linux/*BSD). Falls back to
# Tcl rand() only if /dev/urandom is unreachable; in that case a warning is
# written to the bot log since rand() is NOT suitable for credentials.
# NOTE: symbols are chosen so they don't need shell/IRC escaping (no space,
# quotes, colon, pipe, ampersand, or backslash).
proc znc:randpw {level len} {
    global scriptname
    set pool {}
    if {$level >= 1} { set pool {0 1 2 3 4 5 6 7 8 9} }
    if {$level >= 2} { lappend pool a b c d e f g h i j k l m n o p q r s t u v w x y z }
    if {$level >= 3} { lappend pool A B C D E F G H I J K L M N O P Q R S T U V W X Y Z }
    if {$level >= 4} { lappend pool % @ _ - ! / . , + * = ? # }
    set poolLen [llength $pool]
    if {$poolLen == 0 || $len <= 0} { return "" }

    set bytes ""
    if {[file readable /dev/urandom]} {
        if {[catch {
            set fd [open /dev/urandom rb]
            fconfigure $fd -translation binary -encoding binary
            set bytes [read $fd [expr {$len * 2}]]
            close $fd
        } err]} {
            set bytes ""
            putlog "$scriptname: /dev/urandom read failed ($err), falling back to rand()"
        }
    }

    set out ""
    if {[string length $bytes] >= $len} {
        # Rejection sampling to avoid modulo bias: skip bytes whose value
        # falls into the truncated range (256 % poolLen). For a 62-symbol
        # pool the bias is negligible, but rejection is cheap so we do it.
        set cutoff [expr {256 - (256 % $poolLen)}]
        set idx 0
        set blen [string length $bytes]
        while {[string length $out] < $len && $idx < $blen} {
            binary scan [string index $bytes $idx] cu c
            incr idx
            if {$c >= $cutoff} { continue }
            append out [lindex $pool [expr {$c % $poolLen}]]
        }
        # If rejection ate too many bytes, top up with rand() as a last resort.
        while {[string length $out] < $len} {
            append out [lindex $pool [expr {int(rand()*$poolLen)}]]
        }
    } else {
        putlog "$scriptname: WARNING - using non-cryptographic rand() for password generation"
        for {set i 0} {$i < $len} {incr i} {
            append out [lindex $pool [expr {int(rand()*$poolLen)}]]
        }
    }
    return $out
}

proc znc:vhost:pick {vhostList maxPer} {
    set list {}
    foreach raw $vhostList {
        set ip [string trim $raw]
        if {$ip ne ""} { lappend list $ip }
    }
    if {[llength $list] == 0} { return "" }
    if {$maxPer <= 0} {
        return [lindex $list [expr {int(rand()*[llength $list])}]]
    }
    array set cnt {}
    foreach h [userlist] {
        if {![validuser $h]} { continue }
        if {[catch {set got [getuser $h XTRA bindhost]}]} { continue }
        set got [string trim $got]
        if {$got eq ""} { continue }
        set k [string tolower $got]
        if {![info exists cnt($k)]} { set cnt($k) 0 }
        incr cnt($k)
    }
    set avail {}
    set minCount ""
    foreach ip $list {
        set k [string tolower $ip]
        set n 0
        if {[info exists cnt($k)]} { set n $cnt($k) }
        if {$n >= $maxPer} { continue }
        if {$minCount eq "" || $n < $minCount} {
            set minCount $n
            set avail [list $ip]
        } elseif {$n == $minCount} {
            lappend avail $ip
        }
    }
    if {[llength $avail] == 0} { return "" }
    return [lindex $avail [expr {int(rand()*[llength $avail])}]]
}

## Mail templates

# Shared footer used by every outgoing e-mail. Identifies the sender, the
# support contact, and avoids "who sent me this?" confusion for end users.
proc znc:mail:footer {} {
    global scriptname scriptAuthor scriptServer scriptServerPort
    global scriptNetwork zncnetworkname zncAdminMail znchost
    set f "\n"
    append f "--------------------------------------------------------------\n"
    append f "$scriptNetwork  |  IRC: $scriptServer $scriptServerPort\n"
    append f "Network: $zncnetworkname  |  ZNC host: $znchost\n"
    if {$zncAdminMail ne ""} {
        append f "Support: $zncAdminMail\n"
    }
    append f "This is an automated message generated by\n"
    append f "$scriptname v[znc:version:pretty] (by $scriptAuthor).\n"
    append f "Please do not reply directly unless you want to contact staff.\n"
    return $f
}

# Notify staff that a new ZNC account has been requested and is awaiting
# confirmation. The password is intentionally NOT included: it is generated
# once the request is confirmed (see znc:mail:userConfirmed).
proc znc:mail:requestStaff {user pass} {
    global zncnetworkname znchost zncNonSSLPort zncAdminMail zncRequestMail
    set email ""
    catch { set email [getuser $user COMMENT] }

    set subject "\[ZNC\] New account request: $user ($zncnetworkname)"

    set body ""
    append body "Hello staff,\n\n"
    append body "A new FREE ZNC account has been requested on $zncnetworkname\n"
    append body "and is now waiting for staff approval.\n\n"
    append body "================================================================\n"
    append body " REQUEST DETAILS\n"
    append body "================================================================\n"
    append body [format "  %-18s %s\n" "Network:"         $zncnetworkname]
    append body [format "  %-18s %s\n" "ZNC host:"        $znchost]
    append body [format "  %-18s %s\n" "ZNC port:"        $zncNonSSLPort]
    append body [format "  %-18s %s\n" "Requested user:"  $user]
    append body [format "  %-18s %s\n" "User e-mail:"     $email]
    append body [format "  %-18s %s\n" "Received:"        [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]]
    append body "\n"
    append body "================================================================\n"
    append body " STAFF ACTIONS (run on IRC)\n"
    append body "================================================================\n"
    append body "  Approve  :  !confirm $user\n"
    append body "  Reject   :  !deny $user\n\n"
    append body "If you believe this request is spam or abusive, simply deny it;\n"
    append body "the requester will receive a short automated notification.\n"
    append body [znc:mail:footer]

    znc:mail:send $zncAdminMail $zncRequestMail $subject $body
}

# Welcome mail sent to the end user after staff confirms the account. Contains
# the auto-generated password and all the data needed to connect.
proc znc:mail:userConfirmed {user pass} {
    global zncnetworkname znchost zncNonSSLPort zncAdminMail
    set email ""
    catch { set email [getuser $user COMMENT] }
    if {$email eq ""} { return }

    set subject "\[ZNC\] Your account is ready: $user on $zncnetworkname"

    set body ""
    append body "Hello $user,\n\n"
    append body "Your FREE ZNC account on $zncnetworkname has been approved\n"
    append body "and is now active. Below are the connection details.\n\n"
    append body "================================================================\n"
    append body " ACCOUNT CREDENTIALS\n"
    append body "================================================================\n"
    append body [format "  %-14s %s\n" "Username:" $user]
    append body [format "  %-14s %s\n" "Password:" $pass]
    append body "\n"
    append body "================================================================\n"
    append body " HOW TO CONNECT\n"
    append body "================================================================\n"
    append body "  IRC client (plain):\n"
    append body "    /server $znchost $zncNonSSLPort $user:$pass\n\n"
    append body "  IRC client (SASL / server password):\n"
    append body "    host     : $znchost\n"
    append body "    port     : $zncNonSSLPort\n"
    append body "    username : $user\n"
    append body "    password : $pass\n\n"
    append body "  Web interface:\n"
    append body "    http://$znchost:$zncNonSSLPort/\n\n"
    append body "================================================================\n"
    append body " IMPORTANT NOTES\n"
    append body "================================================================\n"
    append body "  * Please change your password after the first login via the\n"
    append body "    web interface or by sending:\n"
    append body "        /msg \*controlpanel Set Password \$me <newpassword>\n"
    append body "  * Accounts idle for more than 25 days may be removed to free\n"
    append body "    resources. Connect at least once a month to keep it alive.\n"
    append body "  * Do NOT share your credentials; if compromised, contact staff\n"
    append body "    immediately to have the password reset.\n"
    if {$zncAdminMail ne ""} {
        append body "\nFor any issue please write to: $zncAdminMail\n"
    }
    append body "\nEnjoy the service!\n"
    append body [znc:mail:footer]

    znc:mail:send $zncAdminMail $email $subject $body
}

# Audit copy sent to the staff inbox so that every confirmation is tracked.
proc znc:mail:staffConfirmed {user pass} {
    global zncnetworkname znchost zncNonSSLPort zncAdminMail zncRequestMail
    set email ""
    catch { set email [getuser $user COMMENT] }

    set subject "\[ZNC\] Account confirmed: $user ($zncnetworkname)"

    set body ""
    append body "Hello staff,\n\n"
    append body "The following ZNC account has just been CONFIRMED and the\n"
    append body "welcome e-mail with credentials has been queued for the user.\n\n"
    append body "================================================================\n"
    append body " CONFIRMED ACCOUNT\n"
    append body "================================================================\n"
    append body [format "  %-18s %s\n" "Network:"       $zncnetworkname]
    append body [format "  %-18s %s\n" "Host:"          $znchost]
    append body [format "  %-18s %s\n" "Port:"          $zncNonSSLPort]
    append body [format "  %-18s %s\n" "Username:"      $user]
    append body [format "  %-18s %s\n" "Password:"      $pass]
    append body [format "  %-18s %s\n" "User e-mail:"   $email]
    append body [format "  %-18s %s\n" "Confirmed at:"  [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]]
    append body "\n"
    append body "This message is for audit purposes only - no action required.\n"
    append body [znc:mail:footer]

    znc:mail:send $zncAdminMail $zncRequestMail $subject $body
}

# Notify the requester that their request has been denied.
proc znc:mail:deny_to {email} {
    global zncnetworkname zncAdminMail
    if {$email eq ""} { return }

    set subject "\[ZNC\] Your request on $zncnetworkname has been declined"

    set body ""
    append body "Hello,\n\n"
    append body "We are sorry to inform you that your FREE ZNC account request\n"
    append body "on $zncnetworkname has been declined by our staff.\n\n"
    append body "This can happen for several reasons, including but not limited to:\n"
    append body "  * the chosen username is reserved or does not comply with\n"
    append body "    network policies;\n"
    append body "  * a previous account under the same contact was removed;\n"
    append body "  * the request was flagged as automated/abusive.\n\n"
    append body "You are welcome to submit a new request with a different username\n"
    append body "or to contact the staff if you believe this was a mistake.\n"
    if {$zncAdminMail ne ""} {
        append body "\nContact: $zncAdminMail\n"
    }
    append body [znc:mail:footer]

    znc:mail:send $zncAdminMail $email $subject $body
}

proc znc:mail:deny {user} {
    set email ""
    catch { set email [getuser $user COMMENT] }
    znc:mail:deny_to $email
}

# Sent when a previously confirmed account is removed (manual deletion, idle
# cleanup, policy violation, ...). The To: address is passed explicitly
# because by the time this is called the Eggdrop user record may be gone.
proc znc:mail:removed_reason {email reason} {
    global zncnetworkname zncAdminMail
    if {$email eq ""} { return }

    set subject "\[ZNC\] Your account on $zncnetworkname has been removed"

    set body ""
    append body "Hello,\n\n"
    append body "Your ZNC account on $zncnetworkname has been REMOVED.\n\n"
    append body "================================================================\n"
    append body " REMOVAL DETAILS\n"
    append body "================================================================\n"
    append body [format "  %-14s %s\n" "Reason:" $reason]
    append body [format "  %-14s %s\n" "Date:"   [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]]
    append body "\n"
    append body "All data associated with the account has been deleted and cannot\n"
    append body "be restored. You are free to request a new account at any time\n"
    append body "through the usual procedure on IRC.\n"
    if {$zncAdminMail ne ""} {
        append body "\nQuestions or appeals: $zncAdminMail\n"
    }
    append body [znc:mail:footer]

    znc:mail:send $zncAdminMail $email $subject $body
}

proc znc:mail:deleted {user reason} {
    set email ""
    catch { set email [getuser $user COMMENT] }
    znc:mail:removed_reason $email $reason
}

## Request and confirm

# One LoadModule (or LoadNetModule) per utimer; avoids many znc:cp calls in a single interpreter slice.
proc znc:request:loadmods_step {nick user pass netextra mods} {
    if {[llength $mods] == 0} {
        znc:next [list znc:request:apply_step $nick $user $pass $netextra 3]
        return
    }
    znc:cp "LoadModule $user [lindex $mods 0]"
    znc:next [list znc:request:loadmods_step $nick $user $pass $netextra [lrange $mods 1 end]]
}

proc znc:request:netmods_step {nick user pass netextra netname mods} {
    if {[llength $mods] == 0} {
        znc:next [list znc:request:apply_step $nick $user $pass $netextra 7]
        return
    }
    znc:cp "LoadNetModule $user $netname [lindex $mods 0]"
    znc:next [list znc:request:netmods_step $nick $user $pass $netextra $netname [lrange $mods 1 end]]
}

proc znc:request:do_bindhost {nick user pass netextra} {
    znc:next [list znc:request:do_bindhost_run $nick $user $pass $netextra]
}

proc znc:request:do_bindhost_run {nick user pass netextra} {
    global scriptname vhost zncMaxUsersPerBindhost scriptCommandPrefix
    if {[catch {
        if {![info exists zncMaxUsersPerBindhost]} { set zncMaxUsersPerBindhost 3 }
        set picked [znc:vhost:pick $vhost $zncMaxUsersPerBindhost]
        if {$picked ne ""} {
            znc:cp "Set bindhost $user $picked"
            catch { setuser $user XTRA bindhost $picked }
        } else {
            putlog "$scriptname: bindhost pool full (max $zncMaxUsersPerBindhost per IP) - $user created without bindhost"
            znc:notice $nick [znc:fmt bindhost_pool_full $zncMaxUsersPerBindhost $scriptCommandPrefix]
        }
    } err]} {
        putlog "$scriptname: znc:request:do_bindhost_run $user: $err"
        znc:notice $nick [znc:fmt request_zncfail]
    }
    znc:next [list znc:request:apply_step $nick $user $pass $netextra 5]
}

proc znc:request:step7_done {nick user pass} {
    znc:provisioning:clear $user
    znc:notice $nick [znc:fmt request_done $nick $user]
    znc:next [list znc:request:mail_staff $user $pass]
}

proc znc:request:mail_staff {user pass} {
    global scriptname
    if {[catch { znc:mail:requestStaff $user $pass } err]} {
        putlog "$scriptname: request mail staff: $err"
    }
}

proc znc:confirm:mails_after_ok {requester user pass} {
    global scriptname
    if {[catch { znc:mail:userConfirmed $user $pass } err]} {
        putlog "$scriptname: confirm mail user: $err"
    }
    znc:next [list znc:confirm:mails_staff_then_continue $requester $user $pass]
}

proc znc:confirm:mails_staff_then_continue {requester user pass} {
    global scriptname
    if {[catch { znc:mail:staffConfirmed $user $pass } err]} {
        putlog "$scriptname: confirm mail staff: $err"
    }
    znc:next [list znc:confirm:apply_step $requester $user $pass 3]
}

proc znc:deny:after_znc {nick u email} {
    global scriptname
    if {[catch {
        deluser $u
        znc:notice $nick "$u denied and removed."
    } err]} {
        putlog "$scriptname: znc:deny:after_znc $u: $err"
        znc:notice $nick "Deny failed - check bot log."
        return
    }
    znc:next [list znc:mail:deny_to $email]
}

proc znc:deluser:after_znc {nick u email} {
    global scriptname
    if {[catch {
        deluser $u
        znc:notice $nick "$u deleted."
    } err]} {
        putlog "$scriptname: znc:deluser:after_znc $u: $err"
        znc:notice $nick "Delete failed - check bot log."
        return
    }
    znc:next [list znc:mail:removed_reason $email {Deleted by admin}]
}

proc znc:noidle:after_znc {nick u email} {
    global scriptname
    if {[catch {
        deluser $u
        znc:notice $nick "$u deleted (idle)."
    } err]} {
        putlog "$scriptname: znc:noidle:after_znc $u: $err"
        znc:notice $nick "noIdle failed - check bot log."
        return
    }
    znc:next [list znc:mail:removed_reason $email {Idle 15+ days}]
}

proc znc:request:apply_step {nick user pass netextra step} {
    global scriptname zncnetworkname zncDefaultUserModules zncDefaultNetworkModules vhost
    if {[catch {
        switch -- $step {
            0 {
                znc:cp "AddUser $user $pass"
                znc:next [list znc:request:apply_step $nick $user $pass $netextra 1]
            }
            1 {
                znc:block $user
                znc:next [list znc:request:apply_step $nick $user $pass $netextra 2]
            }
            2 {
                znc:next [list znc:request:loadmods_step $nick $user $pass $netextra $zncDefaultUserModules]
            }
            3 {
                znc:cp "AddNetwork $user $zncnetworkname"
                znc:next [list znc:request:apply_step $nick $user $pass $netextra 4]
            }
            4 {
                if {[llength $vhost] > 0} {
                    znc:next [list znc:request:do_bindhost $nick $user $pass $netextra]
                } else {
                    znc:next [list znc:request:apply_step $nick $user $pass $netextra 5]
                }
            }
            5 {
                znc:cp "Set RealName $user $user"
                znc:next [list znc:request:apply_step $nick $user $pass $netextra 6]
            }
            6 {
                if {$netextra ne ""} {
                    znc:next [list znc:request:netmods_step $nick $user $pass $netextra $netextra $zncDefaultNetworkModules]
                } else {
                    znc:next [list znc:request:apply_step $nick $user $pass $netextra 7]
                }
            }
            7 {
                znc:next [list znc:request:step7_done $nick $user $pass]
            }
            default {}
        }
    } err]} {
        znc:provisioning:clear $user
        putlog "$scriptname: znc:request:apply_step $user step $step: $err"
        znc:notice $nick [znc:fmt request_zncfail]
    }
}

proc znc:request {nick host handle chan arg} {
    global scriptCommandPrefix zncPasswordSecurityLevel zncPasswordLength
    global zncShowQuickAck zncRateMaxPerHour zncRateWindowSec
    set parts [split [string trim $arg]]
    set user  [string trim [lindex $parts 0]]
    set email [string trim [lindex $parts 1]]
    # Optional 3rd token: extra network name to add on top of the default one.
    # Kept positional (token #2) instead of the previous nonsensical index 4.
    set netextra [string trim [lindex $parts 2]]

    if {$user eq "" || $email eq ""} {
        znc:notice $nick [znc:fmt request_syntax $scriptCommandPrefix]
        return
    }

    # Rate limit: key on the IRC host portion (user@HOST) so nick spinners hit
    # the same quota. Staff (any bot flag) is exempt so they can rescue users.
    if {![znc:staff:ok $handle] && ![znc:rate:allowed $host]} {
        znc:notice $nick [znc:fmt rate_limited $zncRateMaxPerHour $zncRateWindowSec]
        znc:audit $nick "rate-limit" $host "host=$host user=$user"
        return
    }

    # Username sanity: ZNC usernames must be alphanumeric (plus _/-/.) and
    # short enough to be safe in IRC/mail headers.
    if {![regexp {^[A-Za-z][A-Za-z0-9_.-]{1,31}$} $user]} {
        znc:notice $nick "Invalid username - use 2-32 chars: letters, digits, underscore, dot or dash (must start with a letter)."
        return
    }

    # E-mail sanity: we don't try to be RFC5322-perfect, just reject the most
    # obvious junk so the request mail has a chance of reaching someone.
    if {![regexp {^[^@[:space:]]+@[^@[:space:]]+\.[A-Za-z]{2,}$} $email]} {
        znc:notice $nick "Invalid e-mail address - please supply a real one (e.g. name@example.org)."
        return
    }

    # Sanitize against CR/LF injection in both user and email, even though the
    # regexes above already make that near-impossible.
    if {![znc:safeArgs $user $email]} {
        znc:notice $nick "Your input contains characters that are not accepted."
        return
    }

    if {$zncShowQuickAck} {
        znc:notice $nick [znc:fmt request_quick $nick $user]
    }

    set pass [znc:randpw $zncPasswordSecurityLevel $zncPasswordLength]
    if {![adduser $user]} {
        znc:notice $nick [znc:fmt username_taken]
        return
    }
    setuser $user COMMENT $email
    chattr $user +ZC

    # Record the rate-limit hit only AFTER we've committed to processing the
    # request, so validation failures don't count against quota.
    znc:rate:record $host

    # Start tracking the pending ZNC creation so we can roll back if
    # *controlpanel answers with an error.
    znc:rollback:track $nick $user
    znc:provisioning:mark $user
    znc:audit $nick "request" $user "email=$email host=$host"

    znc:next [list znc:request:apply_step $nick $user $pass $netextra 0]
}

proc znc:confirm:apply_step {requester user pass step {attempt 0}} {
    global zncnetworkname zncircserver zncircserverport zncChannelName scriptname
    global zncConfirmWaitRetrySec zncConfirmWaitMaxRetries
    if {[catch {
        switch -- $step {
            0 {
                znc:cp "Set password $user $pass"
                znc:next [list znc:confirm:apply_step $requester $user $pass 1]
            }
            1 {
                znc:unblock $user
                chattr $user -C
                znc:next [list znc:confirm:apply_step $requester $user $pass 2]
            }
            2 {
                global zncRevealPassOnConfirm scriptname
                if {[info exists zncRevealPassOnConfirm] && $zncRevealPassOnConfirm} {
                    znc:notice $requester [znc:fmt confirm_ok_reveal $user $user $pass]
                } else {
                    znc:notice $requester [znc:fmt confirm_ok $user]
                }
                # Credentials are ALWAYS written to the bot log so an operator
                # can retrieve them if the e-mail delivery fails. The log is
                # usually only readable by the bot owner.
                putlog "$scriptname: CONFIRM $user (requested by $requester) - password: $pass"
                znc:audit $requester "confirm" $user "password emailed"
                znc:next [list znc:confirm:mails_after_ok $requester $user $pass]
            }
            3 {
                set deferAddServer 0
                if {[znc:provisioning:active $user]} {
                    if {![info exists zncConfirmWaitRetrySec] || $zncConfirmWaitRetrySec < 1} {
                        set zncConfirmWaitRetrySec 1
                    }
                    if {![info exists zncConfirmWaitMaxRetries] || $zncConfirmWaitMaxRetries < 1} {
                        set zncConfirmWaitMaxRetries 20
                    }
                    if {$attempt < $zncConfirmWaitMaxRetries} {
                        if {$attempt == 0} {
                            znc:notice $requester "ZNC setup for \"$user\" is still finishing; waiting before attaching the default server."
                        }
                        utimer $zncConfirmWaitRetrySec [list znc:confirm:apply_step $requester $user $pass 3 [expr {$attempt + 1}]]
                        set deferAddServer 1
                    }
                    if {!$deferAddServer} {
                        putlog "$scriptname: confirm wait timeout for $user; forcing AddServer anyway"
                    }
                }
                if {!$deferAddServer} {
                    znc:cp "AddServer $user $zncnetworkname $zncircserver $zncircserverport"
                    znc:next [list znc:confirm:apply_step $requester $user $pass 4]
                }
            }
            4 {
                znc:cp "ADDChan $user $zncnetworkname $zncChannelName"
            }
            default {}
        }
    } err]} {
        putlog "$scriptname: znc:confirm:apply_step $user step $step: $err"
        znc:notice $requester "Confirm failed partway - check bot log. Staff may need to fix the account."
    }
}

proc znc:confirm {requester host handle chan arg} {
    global scriptCommandPrefix zncPasswordSecurityLevel zncPasswordLength
    set user [string trim [lindex [split [string trim $arg]] 0]]
    if {$user eq ""} {
        znc:notice $requester [znc:fmt confirm_syntax $scriptCommandPrefix]
        return
    }
    if {[matchattr $user C]} {
        znc:notice $requester [znc:fmt confirm_wait $user]
        set pass [znc:randpw $zncPasswordSecurityLevel $zncPasswordLength]
        znc:next [list znc:confirm:apply_step $requester $user $pass 0]
        return
    }
    if {[validuser $user]} {
        znc:notice $requester [znc:fmt confirm_already $user]
    } else {
        znc:notice $requester [znc:fmt confirm_none $user]
    }
}

## Rollback on ZNC rejection
##
## *controlpanel does not return a synchronous status code; instead it answers
## with a human-readable NOTICE/PRIVMSG such as:
##   "Error: User [xxx] already exists!"
##   "User xxx added!"
## We keep a per-user pending map populated at request time and cleared either
## on explicit success / error from *controlpanel or via a timeout. If we see
## an error and the Eggdrop account still exists, we delete it so the next
## !request can reuse the same username.

array set zncPending {}     ;# zncPending(lowerUser) -> requesterNick
array set zncPendingT {}    ;# zncPendingT(lowerUser) -> timestamp

proc znc:rollback:track {nick user} {
    global zncPending zncPendingT zncRollbackTimeoutSec
    set key [string tolower $user]
    set zncPending($key)  $nick
    set zncPendingT($key) [clock seconds]
    utimer $zncRollbackTimeoutSec [list znc:rollback:expire $key]
}

proc znc:rollback:expire {key} {
    global zncPending zncPendingT
    catch { unset zncPending($key) }
    catch { unset zncPendingT($key) }
}

# Bind target: receives all PRIVMSG/NOTICE-like traffic that Eggdrop treats as
# private messages. We filter on sender nick "*controlpanel" and then look
# for error or success signatures matching one of the pending users.
proc znc:cp:reply {nick host handle text} {
    global zncPending scriptname
    if {![string match -nocase "*controlpanel*" $nick]} { return }
    # Normalize: strip color/bold codes that some ZNC versions emit.
    regsub -all {[\002\003\017\026\037]} $text "" text
    foreach key [array names zncPending] {
        # Match various phrasings. ZNC master/versions differ slightly.
        # Guard against cross-user false positives: only treat a line as an
        # error for this pending user if the text mentions the username.
        set mentionsKey [string match -nocase "*$key*" $text]
        set isError [expr {
            $mentionsKey && (
                [string match -nocase "*already exists*" $text] ||
                [string match -nocase "*Error*$key*"     $text] ||
                [string match -nocase "*No such user*"   $text] ||
                [string match -nocase "*Invalid*name*"   $text]
            )
        }]
        set isOk [expr {
            [string match -nocase "*User $key added*" $text] ||
            [string match -nocase "*User *$key* added*" $text]
        }]
        if {$isError} {
            set requester $zncPending($key)
            znc:rollback:expire $key
            znc:provisioning:clear $key
            if {[validuser $key]} {
                catch { deluser $key }
            }
            znc:notice $requester "ZNC rejected the account \"$key\": $text  - please try a different username."
            znc:audit $requester "rollback" $key "reason=[string range $text 0 120]"
            putlog "$scriptname: ZNC rollback for $key - $text"
            return
        } elseif {$isOk} {
            znc:rollback:expire $key
            putlog "$scriptname: ZNC confirmed creation of $key"
            return
        }
    }
}

## Command procedures

proc znc:cmd:chemail {nick host handle chan arg} {
    global scriptCommandPrefix
    set parts [split [string trim $arg]]
    set u  [lindex $parts 0]
    set em [lindex $parts 1]
    if {$u eq "" || $em eq ""} {
        znc:notice $nick "Syntax: ${scriptCommandPrefix}chemail <user> <email>"
        return
    }
    if {![znc:safeArgs $u $em]} {
        znc:notice $nick "Your input contains characters that are not accepted."
        return
    }
    if {![regexp {^[^@[:space:]]+@[^@[:space:]]+\.[A-Za-z]{2,}$} $em]} {
        znc:notice $nick "Invalid e-mail address."
        return
    }
    if {![validuser $u]} { znc:notice $nick "Unknown user: $u"; return }
    znc:notice $nick [znc:fmt chemail_busy $u]
    set old ""
    catch { set old [getuser $u COMMENT] }
    setuser $u COMMENT $em
    znc:audit $nick "chemail" $u "old=$old new=$em"
    znc:notice $nick "E-mail updated for $u."
}

proc znc:addvhost_flow {nick u v phase} {
    global scriptname zncnetworkname zncircserver zncircserverport
    if {[catch {
        switch -- $phase {
            0 {
                znc:cp "SetNetwork bindhost $u $zncnetworkname $v"
                znc:next [list znc:addvhost_flow $nick $u $v 1]
            }
            1 {
                znc:cp "AddServer $u $zncnetworkname $zncircserver $zncircserverport"
                znc:next [list znc:addvhost_flow $nick $u $v 2]
            }
            2 {
                znc:cp "Set QuitMsg $u {ZNC vhost change}"
                znc:next [list znc:addvhost_flow $nick $u $v 3]
            }
            3 {
                znc:cp "Reconnect $u $zncnetworkname"
                catch { setuser $u XTRA bindhost [string trim $v] }
                znc:notice $nick "bindhost for $u set to $v (reconnect triggered)."
            }
            default {}
        }
    } err]} {
        putlog "$scriptname: znc:addvhost_flow $u phase $phase: $err"
        znc:notice $nick "addvhost failed - check bot log."
    }
}

proc znc:cmd:addvhost {nick host handle chan arg} {
    global scriptCommandPrefix
    set parts [split [string trim $arg]]
    set u [lindex $parts 0]
    set v [lindex $parts 1]
    if {$u eq "" || $v eq ""} {
        znc:notice $nick "Syntax: ${scriptCommandPrefix}addvhost <user> <bindhost>"
        return
    }
    if {![znc:safeArgs $u $v]} {
        znc:notice $nick "Your input contains characters that are not accepted."
        return
    }
    # Bindhost: either IPv4, IPv6, or a hostname. Accept letters/digits/./:/-
    if {![regexp {^[A-Za-z0-9.:_-]{1,128}$} $v]} {
        znc:notice $nick "Invalid bindhost - use IPv4, IPv6 or a hostname."
        return
    }
    if {![validuser $u]} { znc:notice $nick "Unknown user: $u"; return }
    znc:notice $nick [znc:fmt addvhost_wait $u]
    znc:audit $nick "addvhost" $u "bindhost=$v"
    znc:next [list znc:addvhost_flow $nick $u $v 0]
}

proc znc:cmd:chpass {nick host handle chan arg} {
    global botnick scriptname
    set parts [split [string trim $arg]]
    set u [lindex $parts 0]
    set p [lindex $parts 1]
    if {$u eq "" || $p eq ""} {
        znc:notice $nick "Syntax: /msg $botnick chpass <user> <newpassword>"
        return
    }
    if {![matchattr $handle Q]} {
        znc:notice $nick "Access denied - you need bot flag +Q for this command."
        return
    }
    if {![znc:safeArgs $u $p]} {
        znc:notice $nick "Your input contains characters that are not accepted (no control chars, no spaces in the password)."
        return
    }
    if {![validuser $u]} {
        znc:notice $nick "Unknown user: $u"
        return
    }
    if {[string length $p] < 6} {
        znc:notice $nick "Password too short - use at least 6 characters."
        return
    }
    znc:notice $nick [znc:fmt chpass_busy $u]
    znc:cp "Set password $u $p"
    # Do NOT echo the password back on IRC: the staff member already knows it,
    # and the NOTICE could be captured by logs or screenshots.
    putlog "$scriptname: CHPASS $u (by $handle/$nick)"
    znc:audit $nick "chpass" $u "by handle=$handle"
    znc:notice $nick "Password updated for $u."
}

proc znc:cmd:deny {nick host handle chan arg} {
    global scriptCommandPrefix scriptname
    set u [lindex [split [string trim $arg]] 0]
    if {$u eq ""} { znc:notice $nick "Syntax: ${scriptCommandPrefix}deny <user>"; return }
    if {![znc:safeArg $u]} {
        znc:notice $nick "Your input contains characters that are not accepted."
        return
    }
    if {[matchattr $u C]} {
        znc:notice $nick [znc:fmt deny_wait $u]
        if {[catch {
            set em ""
            catch { set em [getuser $u COMMENT] }
            znc:cp "DelUser $u"
            znc:audit $nick "deny" $u "email=$em"
            znc:deny:after_znc $nick $u $em
        } err]} {
            putlog "$scriptname: deny $u: $err"
            znc:notice $nick "Deny failed - check bot log."
        }
    } elseif {[validuser $u]} {
        znc:notice $nick "$u is already confirmed - use ${scriptCommandPrefix}deluser"
    } else {
        znc:notice $nick "Unknown user: $u"
    }
}

proc znc:cmd:deluser {nick host handle chan arg} {
    global scriptCommandPrefix scriptname
    set u [lindex [split [string trim $arg]] 0]
    if {$u eq ""} { znc:notice $nick "Syntax: ${scriptCommandPrefix}deluser <user>"; return }
    if {![znc:safeArg $u]} {
        znc:notice $nick "Your input contains characters that are not accepted."
        return
    }
    if {![validuser $u]} { znc:notice $nick "Unknown user: $u"; return }
    znc:notice $nick [znc:fmt deluser_wait $u]
    if {[catch {
        set em ""
        catch { set em [getuser $u COMMENT] }
        znc:cp "Set QuitMsg $u {ZNC account deleted}"
        znc:cp "DelUser $u"
        znc:audit $nick "deluser" $u "email=$em"
        znc:deluser:after_znc $nick $u $em
    } err]} {
        putlog "$scriptname: deluser $u: $err"
        znc:notice $nick "Delete failed - check bot log."
    }
}

proc znc:cmd:noidle {nick host handle chan arg} {
    global scriptCommandPrefix scriptname
    set u [lindex [split [string trim $arg]] 0]
    if {$u eq ""} { znc:notice $nick "Syntax: ${scriptCommandPrefix}noidle <user>"; return }
    if {![znc:safeArg $u]} {
        znc:notice $nick "Your input contains characters that are not accepted."
        return
    }
    if {![validuser $u]} { znc:notice $nick "Unknown user: $u"; return }
    znc:notice $nick [znc:fmt noidle_wait $u]
    if {[catch {
        set em ""
        catch { set em [getuser $u COMMENT] }
        znc:cp "Set QuitMsg $u {Deleted - idle 15+ days}"
        znc:cp "DelUser $u"
        znc:audit $nick "noidle" $u "email=$em"
        znc:noidle:after_znc $nick $u $em
    } err]} {
        putlog "$scriptname: noidle $u: $err"
        znc:notice $nick "noIdle failed - check bot log."
    }
}

# !info <user> - staff-only snapshot of a ZNC user stored in the bot.
proc znc:cmd:info {nick host handle chan arg} {
    global scriptCommandPrefix
    set u [lindex [split [string trim $arg]] 0]
    if {$u eq ""} {
        znc:notice $nick "Syntax: ${scriptCommandPrefix}info <user>"
        return
    }
    if {![znc:safeArg $u]} {
        znc:notice $nick "Your input contains characters that are not accepted."
        return
    }
    if {![validuser $u]} {
        znc:notice $nick [znc:fmt info_unknown $u]
        return
    }
    set email    ""
    set bindhost ""
    set laston   ""
    catch { set email    [getuser $u COMMENT] }
    catch { set bindhost [getuser $u XTRA bindhost] }
    catch { set laston   [getuser $u LASTON] }
    set lastonStr "never"
    if {[string is integer -strict $laston] && $laston > 0} {
        set lastonStr [clock format $laston -format {%Y-%m-%d %H:%M:%S}]
    }
    set status "CONFIRMED"
    if {[matchattr $u C]} { set status "PENDING" }
    if {[matchattr $u A]} { append status " +A" }

    znc:notice $nick "\002Info for $u\002  status=$status  email=[expr {$email eq {} ? {<none>} : $email}]  bindhost=[expr {$bindhost eq {} ? {<none>} : $bindhost}]  last-seen=$lastonStr"
}

# !status [user] - public command; if called without arg, shows the status of
# the caller's own handle (if any); with arg shows the status of the given
# username (no private data, just state).
proc znc:cmd:status {nick host handle chan arg} {
    global scriptCommandPrefix znchost zncNonSSLPort
    set u [lindex [split [string trim $arg]] 0]
    if {$u eq ""} { set u $handle }
    if {$u eq "" || $u eq "*"} {
        znc:notice $nick "Usage: ${scriptCommandPrefix}status \[username\]"
        return
    }
    if {![znc:safeArg $u]} { return }
    if {![validuser $u]} {
        znc:notice $nick [znc:fmt status_unknown $u $scriptCommandPrefix]
        return
    }
    if {[matchattr $u C]} {
        znc:notice $nick [znc:fmt status_pending $u]
    } elseif {[matchattr $u Z]} {
        znc:notice $nick [znc:fmt status_active $u $znchost $zncNonSSLPort]
    } else {
        znc:notice $nick "Account \"$u\" exists but is not managed by this script."
    }
}

proc znc:cmd:lastseen {nick host handle chan arg} {
    global znc_lastseen_pending znc_lastseen_clear_timer znc_lastseen_failsafe_timer \
        zncLastseenFailsafeSec znc_lastseen_line_count znc_lastseen_sendq \
        znc_lastseen_rx_buf znc_lastseen_rx_idle_timer znc_lastseen_drain_utimer
    if {[znc:lastseen:session_busy]} {
        znc:notice $nick [znc:fmt lastseen_wait]
        return
    }
    if {![info exists zncLastseenFailsafeSec] || $zncLastseenFailsafeSec < 30} {
        set zncLastseenFailsafeSec 180
    }
    if {[info exists znc_lastseen_clear_timer]} {
        catch {killutimer $znc_lastseen_clear_timer}
    }
    if {[info exists znc_lastseen_failsafe_timer]} {
        catch {killutimer $znc_lastseen_failsafe_timer}
    }
    unset -nocomplain znc_lastseen_clear_timer znc_lastseen_failsafe_timer znc_lastseen_line_count \
        znc_lastseen_sendq znc_lastseen_drain_utimer znc_lastseen_rx_buf znc_lastseen_rx_idle_timer
    set znc_lastseen_line_count 0
    set znc_lastseen_sendq {}
    set znc_lastseen_rx_buf {}
    set znc_lastseen_pending $nick
    set znc_lastseen_failsafe_timer [utimer $zncLastseenFailsafeSec [list znc:lastseen:clear_session 1]]
    znc:notice $nick [znc:fmt lastseen_busy]
    znc:lastseen:send "show"
}

proc znc:listunconf:reply {nick} {
    set l [join [userlist C] ", "]
    if {$l eq ""} {
        znc:notice $nick "No unconfirmed users."
    } else {
        znc:notice $nick "Unconfirmed: $l"
    }
}

proc znc:cmd:listunconf {nick host handle chan arg} {
    znc:notice $nick [znc:fmt listunconf_busy]
    znc:next [list znc:listunconf:reply $nick]
}

proc znc:admins:reply {nick} {
    global zncRequestMail
    set l [join [userlist A] ", "]
    if {$l eq ""} {
        znc:notice $nick "No admins marked online. Mail: $zncRequestMail"
    } else {
        znc:notice $nick "Online admins (flag +A): $l"
    }
}

proc znc:cmd:admins {nick host handle chan arg} {
    znc:notice $nick [znc:fmt admins_busy]
    znc:next [list znc:admins:reply $nick]
}

# !online / !offline
# ------------------
# With no argument:  acts on the caller's own Eggdrop handle.
# With <handle>   :  only +Q admins may change other staff members (self is
#                    always allowed). The target must already be a staff
#                    handle (one of +Q / +Y / +n / +m) for !online to succeed.

proc znc:online:resolveTarget {nick handle arg} {
    global scriptCommandPrefix
    set raw [string trim $arg]
    set token [lindex [split $raw] 0]
    if {$token eq ""} {
        if {$handle eq "" || $handle eq "*"} {
            znc:notice $nick "You have no bot handle on this bot - ask an admin to create one for you."
            return ""
        }
        return $handle
    }
    if {![znc:safeArg $token]} {
        znc:notice $nick "Invalid handle."
        return ""
    }
    if {![string equal -nocase $token $handle] && ![matchattr $handle Q]} {
        znc:notice $nick "Only +Q admins can change other staff members. To toggle yourself just type ${scriptCommandPrefix}online / ${scriptCommandPrefix}offline."
        return ""
    }
    if {![validuser $token]} {
        znc:notice $nick "Unknown handle: $token"
        return ""
    }
    return $token
}

proc znc:cmd:online {nick host handle chan arg} {
    set u [znc:online:resolveTarget $nick $handle $arg]
    if {$u eq ""} { return }
    if {![matchattr $u Q] && ![matchattr $u Y] && ![matchattr $u n] && ![matchattr $u m]} {
        znc:notice $nick "$u is not a staff handle (needs +Q, +Y, +n or +m)."
        return
    }
    znc:notice $nick [znc:fmt online_busy $u]
    if {[matchattr $u A]} {
        znc:notice $nick "$u is already marked online (+A)."
        return
    }
    chattr $u +A
    znc:audit $nick "online" $u "by handle=$handle"
    znc:notice $nick "$u is now marked online (+A)."
}

proc znc:cmd:offline {nick host handle chan arg} {
    set u [znc:online:resolveTarget $nick $handle $arg]
    if {$u eq ""} { return }
    if {![matchattr $u A]} {
        znc:notice $nick "$u is already offline (-A)."
        return
    }
    znc:notice $nick [znc:fmt offline_busy $u]
    chattr $u -A
    znc:audit $nick "offline" $u "by handle=$handle"
    znc:notice $nick "$u is now offline (-A)."
}

proc znc:cmd:version {nick host handle chan arg} {
    global scriptname scriptAuthor scriptServer scriptServerPort
    znc:notice $nick "\002$scriptname\002 v[znc:version:pretty] - written by $scriptAuthor (server: $scriptServer $scriptServerPort)"
}

# Per-topic detailed help. Keep each topic to a few lines: everything is
# sent as individual NOTICE lines so Eggdrop's output queue can flush cleanly.
proc znc:help:topic {nick topic} {
    global scriptCommandPrefix botnick
    set p $scriptCommandPrefix
    switch -nocase -- $topic {
        "request" {
            znc:notice $nick "\002${p}request\002 <username> <email>"
            znc:notice $nick "  Submits a new FREE ZNC account request. Staff must confirm it"
            znc:notice $nick "  before the account becomes usable. You will receive the login"
            znc:notice $nick "  details at the e-mail address you provide."
        }
        "confirm" {
            znc:notice $nick "\002${p}confirm\002 <username>    (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Approves a pending request, generates the password and e-mails"
            znc:notice $nick "  the credentials to the requester."
        }
        "deny" {
            znc:notice $nick "\002${p}deny\002 <username>       (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Rejects a pending request and notifies the requester by e-mail."
        }
        "deluser" {
            znc:notice $nick "\002${p}deluser\002 <username>    (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Permanently deletes a confirmed ZNC account (bot-side + ZNC)."
        }
        "noidle" {
            znc:notice $nick "\002${p}noidle\002 <username>     (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Deletes an account flagged as idle (>15 days) and notifies the"
            znc:notice $nick "  user by e-mail."
        }
        "chemail" {
            znc:notice $nick "\002${p}chemail\002 <username> <newemail>   (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Updates the e-mail address stored in the bot for a ZNC user."
        }
        "chpass" {
            znc:notice $nick "\002chpass\002 <username> <newpass>   (admin: +Q, PRIVATE ONLY)"
            znc:notice $nick "  Resets a ZNC user password. Must be sent with:"
            znc:notice $nick "    /msg $botnick chpass <user> <pass>"
        }
        "addvhost" {
            znc:notice $nick "\002${p}addvhost\002 <username> <ip>   (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Assigns a specific outbound bindhost to an existing user and"
            znc:notice $nick "  triggers a reconnect so the change takes effect."
        }
        "lastseen" {
            znc:notice $nick "\002${p}lastseen\002                (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Queries the ZNC *lastseen module. Output is sent by NOTICE to you"
            znc:notice $nick "  and to staff marked online (+A)."
        }
        "listunconfirmedusers" - "luu" {
            znc:notice $nick "\002${p}listunconfirmedusers\002   (alias: \002${p}luu\002, staff)"
            znc:notice $nick "  Lists all users currently awaiting staff confirmation (+C)."
        }
        "admins" {
            znc:notice $nick "\002${p}admins\002"
            znc:notice $nick "  Shows which admins are currently marked as online (+A)."
        }
        "online" {
            znc:notice $nick "\002${p}online\002 \[handle\]         (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Marks yourself as online (+A). With <handle> and +Q you can mark"
            znc:notice $nick "  another staff member online."
        }
        "offline" {
            znc:notice $nick "\002${p}offline\002 \[handle\]        (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Marks yourself as offline (-A). With <handle> and +Q you can mark"
            znc:notice $nick "  another staff member offline."
        }
        "check" {
            znc:notice $nick "\002${p}check\002 <ip>              (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Counts active outbound connections going to the IRC port from a"
            znc:notice $nick "  given local IP. Useful to audit bindhost saturation."
        }
        "info" {
            znc:notice $nick "\002${p}info\002 <username>          (staff: +n/+m/+Y/+Q)"
            znc:notice $nick "  Displays a one-line snapshot of a user: status (PENDING/CONFIRMED),"
            znc:notice $nick "  e-mail on file, assigned bindhost, and last-seen timestamp."
        }
        "status" {
            znc:notice $nick "\002${p}status\002 \[username\]"
            znc:notice $nick "  Shows the state of a ZNC request: ACTIVE, PENDING or NOT FOUND."
            znc:notice $nick "  Without argument reports your own handle's status."
        }
        "version" {
            znc:notice $nick "\002${p}version\002 - Shows the script name, version and maintainer."
        }
        default {
            znc:notice $nick "No help topic called \"$topic\". Try ${p}help for the list."
        }
    }
}

proc znc:cmd:help {nick host handle chan arg} {
    global scriptCommandPrefix scriptname botnick
    set p $scriptCommandPrefix
    set topic [string tolower [lindex [split [string trim $arg]] 0]]
    set priv [expr {$chan eq $nick}]

    if {$topic ne ""} {
        znc:help:topic $nick $topic
        return
    }

    set isAdmin [expr {[validuser $handle] && [matchattr $handle Q]}]
    set isStaff [expr {[validuser $handle] && ([matchattr $handle n] || [matchattr $handle m] || [matchattr $handle Y])}]

    znc:notice $nick "\002$scriptname\002 v[znc:version:pretty] - command list  (use ${p}help <command> for details)"
    znc:notice $nick "-----------------------------------------------------------------"
    znc:notice $nick "\002User commands\002"
    znc:notice $nick "  ${p}request <user> <email>   Request a FREE ZNC account"
    znc:notice $nick "  ${p}status \[user\]            Check if a request is pending or active"
    znc:notice $nick "  ${p}admins                   Show admins currently online"
    znc:notice $nick "  ${p}help  \[command\]          This help / per-command help"
    znc:notice $nick "  ${p}version                  Script version info"

    if {$isStaff || $isAdmin} {
        znc:notice $nick "\002Staff commands\002  (+n / +m / +Y / +Q)"
        znc:notice $nick "  ${p}confirm <user>                   Approve a pending request"
        znc:notice $nick "  ${p}deny <user>                      Reject a pending request"
        znc:notice $nick "  ${p}deluser <user>                   Delete a confirmed account"
        znc:notice $nick "  ${p}noidle <user>                    Delete an idle account"
        znc:notice $nick "  ${p}chemail <user> <email>           Change a user's e-mail"
        znc:notice $nick "  ${p}addvhost <user> <ip>             Assign outbound bindhost"
        znc:notice $nick "  ${p}info <user>                      Show stored data for a user"
        znc:notice $nick "  ${p}listunconfirmedusers  (${p}luu)     List users awaiting approval"
        znc:notice $nick "  ${p}online  \[handle\]                 Mark yourself (or <handle>) online (+A)"
        znc:notice $nick "  ${p}offline \[handle\]                 Mark yourself (or <handle>) offline (-A)"
        znc:notice $nick "  ${p}lastseen                         Last-seen listing (NOTICE to you + online +A)"
        znc:notice $nick "  ${p}check <ip>                       Audit connections per bindhost"
    }

    if {$isAdmin} {
        znc:notice $nick "\002Admin commands\002  (+Q only - PRIVATE MESSAGE to the bot)"
        znc:notice $nick "  /msg $botnick chpass <user> <newpass>   Reset a user password"
    }

    if {!$priv} {
        znc:notice $nick "Tip: you can also PM me directly, e.g. /msg $botnick help"
    }
}

## PUB wrappers

proc znc:PUB:request {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    znc:request $n $h $hand $c $t
}
proc znc:PUB:confirm {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:confirm $n $h $hand $c $t
}
proc znc:PUB:chemail {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:chemail $n $h $hand $c $t
}
proc znc:PUB:addvhost {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:addvhost $n $h $hand $c $t
}
proc znc:PUB:chpass {n h hand c t} {
    # chpass is private-only on purpose: the password would otherwise be
    # broadcast to everyone in the channel. Refuse politely if used in-channel.
    if {![znc:pub:channelOk $n $c]} { return }
    znc:notice $n "For security reasons chpass must be sent in PRIVATE MESSAGE: /msg $::botnick chpass <user> <pass>"
}
proc znc:PUB:deny {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:deny $n $h $hand $c $t
}
proc znc:PUB:deluser {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:deluser $n $h $hand $c $t
}
proc znc:PUB:noidle {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:noidle $n $h $hand $c $t
}
proc znc:PUB:lastseen {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:lastseen $n $h $hand $c $t
}
proc znc:PUB:listunconf {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:listunconf $n $h $hand $c $t
}
proc znc:PUB:admins {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    znc:cmd:admins $n $h $hand $c $t
}
proc znc:PUB:online {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:online $n $h $hand $c $t
}
proc znc:PUB:offline {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:offline $n $h $hand $c $t
}
proc znc:PUB:info {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:info $n $h $hand $c $t
}
proc znc:PUB:status {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    znc:cmd:status $n $h $hand $c $t
}
proc znc:PUB:help {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    znc:cmd:help $n $h $hand $c $t
}
proc znc:PUB:version {n h hand c t} {
    if {![znc:pub:channelOk $n $c]} { return }
    znc:cmd:version $n $h $hand $c $t
}

## MSG wrappers

proc znc:MSG:request {n h hand t} { znc:request $n $h $hand $n $t }
proc znc:MSG:confirm {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:confirm $n $h $hand $n $t
}
proc znc:MSG:chemail {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:chemail $n $h $hand $n $t
}
proc znc:MSG:addvhost {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:addvhost $n $h $hand $n $t
}
proc znc:MSG:chpass {n h hand t} {
    if {![znc:mustAdmin $n $hand]} { return }
    znc:cmd:chpass $n $h $hand $n $t
}
proc znc:MSG:deny {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:deny $n $h $hand $n $t
}
proc znc:MSG:deluser {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:deluser $n $h $hand $n $t
}
proc znc:MSG:noidle {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:noidle $n $h $hand $n $t
}
proc znc:MSG:listunconf {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:listunconf $n $h $hand $n $t
}
proc znc:MSG:info {n h hand t} {
    if {![znc:mustStaff $n $hand]} { return }
    znc:cmd:info $n $h $hand $n $t
}
proc znc:MSG:status {n h hand t} { znc:cmd:status $n $h $hand $n $t }
proc znc:MSG:help {n h hand t} { znc:cmd:help $n $h $hand $n $t }
proc znc:MSG:version {n h hand t} { znc:cmd:version $n $h $hand $n $t }

proc znc:lastseen:ingest {nick host handle text} {
    global znc_lastseen_failsafe_timer znc_lastseen_line_count \
        znc_lastseen_rx_buf znc_lastseen_rx_idle_timer zncLastseenRxIdleSec
    if {$text eq ""} { return }
    if {![info exists zncLastseenRxIdleSec] || $zncLastseenRxIdleSec < 1} {
        set zncLastseenRxIdleSec 3
    }
    if {![info exists znc_lastseen_line_count]} { set znc_lastseen_line_count 0 }
    if {[info exists znc_lastseen_failsafe_timer]} {
        catch {killutimer $znc_lastseen_failsafe_timer}
        unset -nocomplain znc_lastseen_failsafe_timer
    }
    if {![info exists znc_lastseen_rx_buf]} { set znc_lastseen_rx_buf {} }
    foreach rawline [split $text "\n"] {
        set line [string trimright $rawline]
        if {$line eq ""} { continue }
        incr znc_lastseen_line_count
        lappend znc_lastseen_rx_buf $line
    }
    if {[info exists znc_lastseen_rx_idle_timer]} {
        catch {killutimer $znc_lastseen_rx_idle_timer}
    }
    set znc_lastseen_rx_idle_timer [utimer $zncLastseenRxIdleSec [list znc:lastseen:flush_rx]]
}

proc znc:chatproc {nick host handle text} {
    if {![string match -nocase "*lastseen" $nick]} { return }
    znc:lastseen:ingest $nick $host $handle $text
}

proc znc:notc:lastseen {nick uhost hand dest text} {
    global botnick
    if {![string equal -nocase $dest $botnick]} { return }
    if {![string match -nocase "*lastseen" $nick]} { return }
    znc:lastseen:ingest $nick $uhost $hand $text
}

proc znc:raw_lastseen_ingest {from msg} {
    global botnick zncLastseenDebug scriptname
    set f $from
    if {[string index $f 0] eq ":"} { set f [string range $f 1 end] }
    set src [lindex [split $f !] 0]
    if {![string match -nocase "*lastseen" $src]} { return 0 }
    set m [string trimleft $msg]
    if {![regexp {^(\S+)\s+:(.*)$} $m -> target payload]} {
        if {![regexp {^(\S+)\s+(.*)$} $m -> target payload]} { return 0 }
    }
    if {![string equal -nocase $target $botnick]} { return 0 }
    if {[info exists zncLastseenDebug] && $zncLastseenDebug} {
        putlog "$scriptname: lastseen raw from=$src payload=[string length $payload] chars"
    }
    znc:lastseen:ingest $src "" "" $payload
    return 1
}
proc znc:raw:privmsg {from code msg} {
    if {![string equal -nocase $code "PRIVMSG"]} { return 0 }
    return [znc:raw_lastseen_ingest $from $msg]
}
proc znc:raw:notc {from code msg} {
    if {![string equal -nocase $code "NOTICE"]} { return 0 }
    return [znc:raw_lastseen_ingest $from $msg]
}
proc znc:rawt:privmsg {from code msg tagdict} {
    if {![string equal -nocase $code "PRIVMSG"]} { return 0 }
    return [znc:raw_lastseen_ingest $from $msg]
}
proc znc:rawt:notc {from code msg tagdict} {
    if {![string equal -nocase $code "NOTICE"]} { return 0 }
    return [znc:raw_lastseen_ingest $from $msg]
}

proc znc:join:notice {nick host handle chan} {
    global zncChannelName zncnetworkname scriptCommandPrefix
    if {![string equal -nocase $chan $zncChannelName]} { return }
    putquick "NOTICE $nick :[znc:fmt join1 $zncChannelName $zncnetworkname $scriptCommandPrefix]"
    putquick "NOTICE $nick :[znc:fmt join2 $scriptCommandPrefix]"
}

# Count how many outbound connections are currently open from <ip> towards
# the configured IRC port. Uses pure Tcl parsing and prefers `ss` (modern)
# with a graceful fallback to `netstat` (legacy, still common on older
# systems). Both outputs are interpreted line-by-line in the same Tcl loop,
# so no external pipe/grep/cut chain is required.
proc znc:check:run {nick ip} {
    global zncircserverport scriptname

    set out ""
    set used ""
    foreach try {
        {ss   -ntu state established}
        {ss   -ntu}
        {netstat -ntu}
    } {
        if {[catch { set out [exec {*}$try] } err]} {
            set out ""
            continue
        }
        if {$out ne ""} { set used [lindex $try 0]; break }
    }
    if {$out eq ""} {
        znc:notice $nick "check failed: neither 'ss' nor 'netstat' are available or they returned nothing."
        putlog "$scriptname: znc:check:run: no usable socket tool found"
        return
    }

    # We only care about rows that:
    #  * mention the IRC server port (either as local or remote end);
    #  * are NOT listening sockets;
    #  * contain the requested local IP.
    set count 0
    foreach line [split $out "\n"] {
        set line [string trim $line]
        if {$line eq ""} { continue }
        if {[string match -nocase "*LISTEN*" $line]} { continue }
        if {[string first ":$zncircserverport" $line] < 0} { continue }
        # Match $ip as a colon-terminated token so 192.168.1.1 doesn't also
        # match 192.168.1.10, or as a bracketed IPv6 token [::1]:port.
        if {[string first "${ip}:" $line] < 0 &&
            [string first "\[${ip}\]:" $line] < 0} { continue }
        incr count
    }

    set cap 254
    if {$count >= $cap} {
        znc:notice $nick "$ip has $count connection(s) on port $zncircserverport - over the safe limit of $cap. Pick another bindhost. (source: $used)"
        return
    }
    if {$count == 0} {
        znc:notice $nick "No active connections seen for $ip on port $zncircserverport right now. (source: $used)"
    } else {
        znc:notice $nick "$ip has $count connection(s) on port $zncircserverport. (source: $used)"
    }
}

proc znc:PUB:check {n h hand c arg} {
    global scriptCommandPrefix
    if {![znc:pub:channelOk $n $c]} { return }
    if {![znc:mustStaff $n $hand]} { return }
    set ip [lindex [split [string trim $arg]] 0]
    if {$ip eq ""} {
        znc:notice $n "Syntax: ${scriptCommandPrefix}check <ip>"
        return
    }
    znc:notice $n "Running check for $ip..."
    znc:next [list znc:check:run $n $ip]
}

## Bind registration
set p $scriptCommandPrefix

bind PUB -  "${p}request" znc:PUB:request
bind PUB -  "${p}confirm" znc:PUB:confirm
bind PUB -  "${p}chemail" znc:PUB:chemail
bind PUB -  "${p}addvhost" znc:PUB:addvhost
bind PUB -  "${p}chpass" znc:PUB:chpass
bind PUB -  "${p}deny" znc:PUB:deny
bind PUB -  "${p}deluser" znc:PUB:deluser
bind PUB -  "${p}noidle" znc:PUB:noidle
bind PUB -  "${p}lastseen" znc:PUB:lastseen
bind PUB -  "${p}listunconfirmedusers" znc:PUB:listunconf
bind PUB -  "${p}luu" znc:PUB:listunconf
bind PUB -  "${p}admins" znc:PUB:admins
bind PUB -  "${p}online" znc:PUB:online
bind PUB -  "${p}offline" znc:PUB:offline
bind PUB -  "${p}info" znc:PUB:info
bind PUB -  "${p}status" znc:PUB:status
bind PUB -  "${p}help" znc:PUB:help
bind PUB -  "${p}version" znc:PUB:version
bind PUB -  "${p}check" znc:PUB:check

bind MSG -  "request" znc:MSG:request
bind MSG -  "confirm" znc:MSG:confirm
bind MSG -  "chemail" znc:MSG:chemail
bind MSG -  "addvhost" znc:MSG:addvhost
bind MSG -  "chpass" znc:MSG:chpass
bind MSG -  "deny" znc:MSG:deny
bind MSG -  "deluser" znc:MSG:deluser
bind MSG -  "noidle" znc:MSG:noidle
bind MSG -  "listunconfirmedusers" znc:MSG:listunconf
bind MSG -  "luu" znc:MSG:listunconf
bind MSG -  "info" znc:MSG:info
bind MSG -  "status" znc:MSG:status
bind MSG -  "help" znc:MSG:help
bind MSG -  "version" znc:MSG:version

bind raw - PRIVMSG znc:raw:privmsg
bind raw - NOTICE znc:raw:notc
if {[catch {
    bind rawt - PRIVMSG znc:rawt:privmsg
    bind rawt - NOTICE znc:rawt:notc
} err]} {
    global scriptname
    putlog "$scriptname: optional IRCv3 bind rawt skipped: $err"
}
bind notc - * znc:notc:lastseen
bind msgm -|- * znc:chatproc
bind msgm -|- * znc:cp:reply
bind join -|- * znc:join:notice

## Startup banner
proc znc:banner:log {} {
    global scriptname scriptNetwork scriptAuthor
    global scriptServer scriptServerPort scriptUpdater scriptUpdaterMail
    global zncMailMethod zncChannelName zncnetworkname znchost zncNonSSLPort
    global scriptCommandPrefix vhost zncMaxUsersPerBindhost scriptdebug
    set p $scriptCommandPrefix
    putlog "================================================================"
    putlog " $scriptname  v[znc:version:pretty]"
    putlog "   Written by     : $scriptAuthor"
    putlog "   IRC server     : $scriptServer $scriptServerPort"
    putlog "   Network        : $scriptNetwork ($zncnetworkname)"
    putlog "   ZNC listener   : $znchost:$zncNonSSLPort"
    putlog "   Public channel : $zncChannelName  (enable with: .chanset $zncChannelName +znc)"
    putlog "   Mail transport : $zncMailMethod"
    putlog "   Bindhost pool  : [llength $vhost] IP(s), max $zncMaxUsersPerBindhost user(s) per IP"
    putlog "   Maintainer     : $scriptUpdater <$scriptUpdaterMail>"
    if {$scriptdebug} { putlog "   \[DEBUG MODE ENABLED\]" }
    putlog "----------------------------------------------------------------"
    putlog " Public commands (on channels with +znc flag):"
    putlog "   ${p}request <user> <email>   -  request a FREE ZNC account"
    putlog "   ${p}status \[username\]        -  check request / account status"
    putlog "   ${p}admins                   -  show online admins"
    putlog "   ${p}help \[command\]           -  in-channel help"
    putlog "   ${p}version                  -  show script version"
    putlog " Staff commands (require +n / +m / +Y / +Q):"
    putlog "   ${p}confirm  ${p}deny  ${p}deluser  ${p}noidle  ${p}chemail"
    putlog "   ${p}addvhost  ${p}info  ${p}lastseen"
    putlog "   ${p}listunconfirmedusers (${p}luu)  ${p}online  ${p}offline  ${p}check"
    putlog " Admin commands (+Q only, PRIVATE MSG to the bot):"
    putlog "   chpass <user> <newpass>"
    putlog "================================================================"
}
znc:banner:log
