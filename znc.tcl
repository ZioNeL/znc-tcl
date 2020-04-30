###############################################################################
### Preconfiguration please don't change...
### Script Logic ## Handle with care!
###############################################################################
set scriptname "Free ZNC management script"
set scriptOwner "Christoph Kern"
set scriptOwnerMail "Sheogorath@shivering-isles.de"
set scriptUpdater "ZioN"
set scriptUpdaterMail "zion@universalnet.org"
set scriptchannel "#ZNC"
set scriptOwnerNetwork "irc.shivering-isles.de"
set scriptUpdaterNetwork "irc.universalnet.org @ UniversalNet"
set scriptversion "0.7.0.1"
set scriptversionUpdated "2.5"
set scriptdebug 0

putlog "$scriptname loading configuration..."

###############################################################################
### End of Preconfig
###############################################################################


###############################################################################
### Start of config
###############################################################################


### Script --------------------------------------------------------------------
# Script specific settings
#
#
###----------------------------------------------------------------------------

## set to 0 to minimize script putlog part
set scriptUseBigHeader 1

## Advertice ScriptOwner
set adverticeScriptOwner 0

## Prefix for triggering Bot Commands things like !request or .request
set scriptCommandPrefix "!"

## Sendmailpath !!!!! YOU REALLY NEED TO CHECK THE PATH !!!!!
set sendmailPath "/usr/sbin/sendmail"

### ZNC -----------------------------------------------------------------------
# Here you can configure your whole ZNC settings
#
#
###----------------------------------------------------------------------------

## ZNC Network name
set zncnetworkname "your_Network_name"

## Server Port name
#set port "6667"

## ZNC server name
#set server "irc.universalnet.org"

## The prefix set for Modules for Bot's ZNC-User
set zncprefix "*"

## The DNS-Host of your ZNC Server
set znchost "hostname_or_ip_of_znc_server"

## The ZNC NON-SSL Port, if not exists set ""
set zncNonSSLPort "1234"

## The ZNC SSL Port, if not exists set ""
set zncSSLPort ""

## The ZNC-Webinterface NON-SSL Port, if not exists set ""
set zncWebNonSSLPort "1234"

## The ZNC-Webinterface SSL Port, if not exists set ""
set zncWebSSLPort ""

## The Name of server support/admin
set zncAdminName "Name_of_ZNC_Admin"

## The E-Mail address of server support/admin
set zncAdminMail "znc-admin@example.org"
set zncRequestMail "znc-request@example.org"

## Define the ZNC Vhosts Here. Please Keep in mind that these VHOSTS must be UP on server`s network interfaces first !!! 
set vhost {
"10.0.1.2"
"10.0.1.3"
"10.0.1.4"
"10.0.1.5"
"10.0.1.6"
"10.0.1.7"
"10.0.1.8"
"10.0.1.9"
"10.0.1.10"
"10.0.1.11"
}

## The ZNC IRC Server
set zncircserver "irc.example.org"
set zncircserverport "6667"
set zncChannelName "#ZNC"


#E-mail Seetings
proc mail:sendTo:user { from to subject content {cc "" } } {
        global sendmailPath zncnetworkname zncAdminMail
        set msg {From: UniversalNet FreeZNC <znc-request@universalnet.org>}
        append msg \n "To: " [join $to , ]
        append msg \n "Cc: " [join $cc , ]
        append msg \n "Subject: $subject"
        append msg \n\n $content

        exec $sendmailPath -oi -t << $msg
}

## The Level of Security for the random generated password for new ZNC-users (recommanded is 3 means [a-zA-Z0-9])
set zncPasswordSecurityLevel 3

## The Length of the automatic generated password)
set zncPasswordLength 16

### Optional - Preconfiguration -----------------------------------------------
# Default Modules and Networks
# !!!!!!! DISABLED !!!!!!!! FEATURE COMMING SOON !!!!!!!!
#
###----------------------------------------------------------------------------

## Default User Modules loaded, if not exists set { } if you use arguments do it like that: "autoreply \"I'll be back soon\""
set defaultUserModules { "chansaver" "controlpanel" "buffextras" "autoreply \"I'll be back soon\""}
set zncDefaultUserModules {  }

## Default User Modules loaded, if not exists set { } if you use arguments do it like that: "autoreply \"I'll be back soon\""
set defaultUserModules { "chansaver" "controlpanel" "buffextras" "autoreply \"I'll be back soon\""}
set zncDefaultNetworkModules {  }

### Preconfigured Networks
## Enable Preconfigured Networks
set usePreconfiguredNetworks 0

## Array of Preconfigured Networks (only works if usePreconfiguredNetworks is set to 1 )
array set knownNetworks {
        NetworkName "server_adress server_port" 
}
## Forces to 1 Network  !!!!!!! DISABLED !!!!!!!! FEATURE COMMING SOON !!!!!!!!
#set zncEnforcedNetwork "irc.shivering-isles.de +6697"
set zncEnforcedNetwork "irc.example.org 6666"


### Optional - Topic Settings -------------------------------------------------
# Topic Settings
# !!!!!!! DISABLED !!!!!!!! FEATURE COMMING SOON !!!!!!!!
#
###----------------------------------------------------------------------------

## Change Topic 1 means on 0 means off
set zncTopic 1

## Show Number of ZNC users in Topic
set zncTopicUsercount 1

## Show Serverdata in Topic
set zncTopicServerdata 1

## Show Name of server support/admin
set zncTopicShowAdmin 1

## Topicprefix
set zncTopicPrefix ""

## GreetSuffix
set zncTopicSuffix ""


### Optional - Greeting Settings ----------------------------------------------
# Settings for Greeting
# !!!!!!! DISABLED !!!!!!!! FEATURE COMMING SOON !!!!!!!!
#
###----------------------------------------------------------------------------

## Show Greeting 1 means on 0 means off
set zncGreeting 1

## Greet prefix (possible values for replace: %nick% %channel%)
set zncGreetPrefix "\00300,01"

## Greet suffix (possible values for replace: %nick% %channel%)
set zncGreetSuffix "\003"

## Greet Messages (possible values for replace: %nick% %channel% %zncAdminName% %zncAdminMail% %zncNonSSLPort% %zncSSLPort% %zncWebSSLPort% %zncWebNonSSLPort% %znchost%)
set zncGreetings {
        "Hello %nick%, stay here or manage you ZNC Account via https://%znchost%:%zncWebSSLPort%!"
        "Hello %nick%, welcome to %channel%!"
        "Welcome %nick%, %channel% is for ZNC management. To request a ZNC-Account use !help request"
        }


### Optional - Advertice ------------------------------------------------------
# Settings for advertice your network
# !!!!!!! DISABLED !!!!!!!! FEATURE COMMING SOON !!!!!!!!
#
###----------------------------------------------------------------------------

## Do Advertice 1 means on 0 means off (if 0 scriptAdvertice is off, too)
set zncAdvertice 1

## Show Number of ZNC users in Advertice
set zncAdverticeUsercount 1

## Show Serverdata in Topic
set zncAdverticeServerdata 1

## Show Name of server support/admin
set zncAdverticeShowAdmin 1

## Sentences for Advertice
#set zncAdverticeSenteces { } #disabled
set zncAdverticeSenteces {
        "Get your Free ZNC now!"
        ""}


###############################################################################
### End of Config
###############################################################################

###############################################################################
### Script Logic ## Handle with care! (If you change 1 character my support ends)
###############################################################################
putlog "$scriptname configuration loaded"
putlog "$scriptname loading script..."

if { $scriptUseBigHeader } {
        putlog "$scriptname is wirtten by $scriptOwner and updated by $scriptUpdater"
        putlog "If you need help join irc://$scriptUpdaterNetwork/$scriptchannel"
        putlog "If you can't join or want to contact me inanother way, you can E-Mail to $scriptOwnerMail"
        putlog "Enjoin your work with $scriptname"
}

if { $scriptdebug } {
        putlog "!!!!!!!!!!!!WARNING!!!!!!!!!!!!!!"
        putlog "RUNNING SCRIPT IN DEBUG MODE! DO NOT RUN PRODUCTIVE!"
}

### Bot Commands --------------------------------------------------------------

proc znc:request { nick host handle chan text } {
        global scriptCommandPrefix zncPasswordSecurityLevel zncPasswordLength zncnetworkname zncDefaultUserModules zncDefaultNetworkModules usePreconfiguredNetworks zncnetworkname vhost
        set username [lindex $text 0]
        set email [lindex $text 1]
        set server [lindex $text 2]
        set port [lindex $text 3]
        set networkname [lindex $text 4]


        if { $email == ""} {
                puthelp "NOTICE $nick :${scriptCommandPrefix}request syntax is \"${scriptCommandPrefix}request <zncusername> <e-mail-address> \" for more please use \"${scriptCommandPrefix}help request" 
                return
        } else {
		set password [znc:helpfunction:generatePassword  $zncPasswordSecurityLevel $zncPasswordLength ]
                if [ adduser $username ] {
                        setuser $username COMMENT $email
                        chattr $username +ZC
                        znc:controlpanel:AddUser $username $password
                        znc:blockuser:block $username
                        znc:helpfunction:loadModuleList $username $zncDefaultUserModules
	                znc:controlpanel:AddNetwork $username $zncnetworkname
                        znc:controlpanel:Set bindhost $username [lindex $vhost [rand [llength $vhost]]]
                        znc:controlpanel:Set RealName $username $username
			mail:simply:sendUserRequest2 $username $password $vhost
                        if { $networkname != ""} {
                                set preServer ""
                                if { $usePreconfiguredNetworks } {
                                        set preServer [array names knownNetworks -exact [string tolower $networkname]]
                                }
                                znc:helpfunction:loadNetModuleList $username $networkname $zncDefaultNetworkModules
                                if { $preServer != "" } {
                                        foreach {networkname networkserver} [array get knownNetworks [string tolower $networkname]] {
                                        }
                                } else {
                                        if { $port != "" } {
                                        }
                                }
                        }
                        puthelp "NOTICE $nick :Hey $nick, your request for $username is noticed and after confirm by an administrator you'll get an email with all needed data."
                } else {
                        puthelp "NOTICE $nick :Sry, but your wanted username is already in use..."
                }
        }
}

proc znc:confirm {requester host handle chan text} {
        global scriptCommandPrefix zncPasswordSecurityLevel zncPasswordLength zncnetworkname zncircserver zncircserverport zncChannelName
        set username [lindex $text 0]
        set vhost [lindex $text 1]

        if {$username == "" } {
                puthelp "NOTICE $requester :${scriptCommandPrefix}Confirm syntax is \"${scriptCommandPrefix}Confirm <zncusername>\" for more please use \"${scriptCommandPrefix}help Confirm"
        }
        if [ matchattr $username C] {
                set password [znc:helpfunction:generatePassword $zncPasswordSecurityLevel $zncPasswordLength ]
                znc:controlpanel:Set "password" $username $password
                mail:simply:sendUserRequest $username $password
		mail:simply:sendUserRequest3 $username $password
                znc:blockuser:unblock $username
                chattr $username -C
                puthelp "NOTICE $requester :$username is now confirmed."
                puthelp "NOTICE $requester :To Connect to ZNC-Server use as IDENT ${username} and \"${password}\" as server-password"
                znc:controlpanel:AddServer $username $zncnetworkname $zncircserver:$zncircserverport
                znc:controlpanel:AddChan $username $zncnetworkname $zncChannelName
        } elseif [ validuser $username ] {
                puthelp "NOTICE $requester :$username is already confirmed."
        } else {
                puthelp "NOTICE $requester :$username does not exist"
        }
}

proc znc:addvhost {nick host handle chan text} {
        global scriptCommandPrefix zncnetworkname zncircserver zncircserverport zncChannelName 
        set username [lindex $text 0]
        set vhost [lindex $text 1]
        if {$username == "" } {
                puthelp "NOTICE $nick :${scriptCommandPrefix}addvhost syntax is \"${scriptCommandPrefix}addvhost <zncusername> <vhost>\" for more please use \"${scriptCommandPrefix}help addvhost"
        }
        if [ validuser $username ] {
                znc:controlpanel:SetNetwork bindhost $username $zncnetworkname $vhost
                znc:controlpanel:AddServer $username $zncnetworkname $zncircserver:$zncircserverport
                znc:controlpanel:Set QuitMsg $username "ZNC Account vhost change"
                znc:controlpanel:Reconnect $username $zncnetworkname
        } elseif [ validuser $username ] {
                puthelp "NOTICE $nick :$username has now $vhost as new vhost."
        } else {
                puthelp "NOTICE $nick :$username does not exist"
        }
}


proc znc:chpass {nick host handle text} {
#        global scriptCommandPrefix
        set username [lindex $text 0]
        set newpass [lindex $text 1]
        if {$username == "" } {
                puthelp "NOTICE $nick :${scriptCommandPrefix}chpass syntax is \"${scriptCommandPrefix}chpass <zncusername> <newpassword>\" for more please use \"${scriptCommandPrefix}help chpass"
        }
        if [ validuser $username ] {
                znc:controlpanel:Set password $username $newpass
                puthelp "NOTICE $nick :Password for $username has been set to $newpass."
        } else {
                puthelp "NOTICE $nick :$username does not exist"
        }
}

proc znc:deny {nick host handle chan text} {
        global scriptCommandPrefix
        set username [lindex $text 0]
        if {$username == "" } {
                puthelp "NOTICE $nick :${scriptCommandPrefix}Deny syntax is \"${scriptCommandPrefix}Deny <zncusername>\" for more please use \"${scriptCommandPrefix}help Deny"
        }
        if [ matchattr $username C ] {
                mail:simply:sendUserDeny $username
                znc:controlpanel:DelUser $username
                deluser $username
                puthelp "NOTICE $nick :$username is now denied."
        } elseif [ validuser $username ] {
                puthelp "NOTICE $nick :$username is already confirmed. Use \"${scriptCommandPrefix}DelUser <username>\" to remove"
        } else {
                puthelp "NOTICE $nick :$username does not exist"
        }
}

proc znc:delUser {nick host handle chan text} {
        global scriptCommandPrefix
        set username [lindex $text 0]
        if {$username == "" } {
                puthelp "NOTICE $nick :${scriptCommandPrefix}DelUser syntax is \"${scriptCommandPrefix}DelUser <zncusername>\" for more please use \"${scriptCommandPrefix}help DelUser"
        }
        if [ validuser $username ] {
                znc:controlpanel:Set QuitMsg $username "ZNC Account deleted. User Request!"
                mail:simply:sendUserDel $username
                znc:controlpanel:DelUser $username
                deluser $username
                puthelp "NOTICE $nick :$username is now deleted."
        } else {
                puthelp "NOTICE $nick :$username does not exist"
        }
}

proc znc:noIdle {nick host handle chan text} {
        global scriptCommandPrefix
        set username [lindex $text 0]
        if {$username == "" } {
                puthelp "NOTICE $nick :${scriptCommandPrefix}noIdle syntax is \"${scriptCommandPrefix}noIdle <zncusername>\" for more please use \"${scriptCommandPrefix}help noIdle"
        }
        if [ validuser $username ] {
		znc:controlpanel:Set QuitMsg $username "ZNC Account deleted. User was inactive for 15 days or more."
                mail:simply:sendUsernoIdle $username
                znc:controlpanel:DelUser $username
                deluser $username
                puthelp "NOTICE $nick :$username is now deleted because of no login for more than 15 days"
        } else {
                puthelp "NOTICE $nick :$username does not exist"
        }
}

proc znc:lastseen {nick host handle chan text} {
        global scriptCommandPrefix zncprefix partychan zncChannelName 
                znc:lastseen:show
		znc:chatproc
}

proc znc:listUnconfirmed {nick host handle chan text} {
        global scriptCommandPrefix
        set UnConfirmedList [join [ userlist C ] ,]
        if { $UnConfirmedList != "" } {
                puthelp "NOTICE $nick :Unconfirmed users: $UnConfirmedList"
        } else {
                puthelp "NOTICE $nick :no unconfirmed users"
        }
}

proc znc:Admins {nick host handle chan text} {
        global scriptCommandPrefix zncRequestMail
        set Admins [join [ userlist A ] ,]
        if { $Admins != "" } {
                puthelp "NOTICE $nick :Free-ZNC Admins: $Admins"
        } else {
		puthelp "NOTICE $nick :no Free-ZNC Admins are online at this moment! Please try again later or send an e-mail to $zncRequestMail with your question or problem."
        }
}

proc znc:Online {requester host handle chan text} {
        global scriptCommandPrefix 
        set username [lindex $text 0]

        if {$username == "" } {
                puthelp "NOTICE $requester :${scriptCommandPrefix}Online syntax is \"${scriptCommandPrefix}Online <username>\" for more please use \"${scriptCommandPrefix}help Online"
        } elseif [ matchattr $username QY] {
                chattr $username +A
                puthelp "NOTICE $requester :Admin $username is now Online."
        } else {
                puthelp "NOTICE $requester :$username does not have the right to be set as ONLINE or does not exist"
        }
}

proc znc:Offline {requester host handle chan text} {
        global scriptCommandPrefix
        set username [lindex $text 0]

        if {$username == "" } {
                puthelp "NOTICE $requester :${scriptCommandPrefix}Offline syntax is \"${scriptCommandPrefix}Offline <username>\" for more please use \"${scriptCommandPrefix}help Offline"
        } elseif [ matchattr $username A ] {
                chattr $username -A
                puthelp "NOTICE $requester :Admin $username is now Offline."
        } else {
                puthelp "NOTICE $requester :$username does not have the right to be set as OFFLINE or does not exist"
        }
}

proc znc:help {nick host handle chan text} {
        global scriptCommandPrefix zncAdminName scriptname botnick
        set helpcontext [lindex $text 0]
        if { $helpcontext != "" } {
                switch [string tolower $helpcontext] {
                        request {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}Request"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}Request you can request an ZNC-Account that Account"
                                puthelp "NOTICE $nick :#is just waiting for a confirm or deny by $zncAdminName. If it is confirmed you'll"
                                puthelp "NOTICE $nick :#get an e-mail with address and password for your Account."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#You can instantly add a virtualhost ."
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}request <zncusername> <e-mail-address> <vhost>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}request Foo foo@bar.com 10.0.1.30"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick request <zncusername> <e-mail-address> <vhost>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick request Foo foo@bar.com 10.0.1.30"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                        listunconfirmedusers {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}ListUnconfirmedUsers"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}ListUnconfirmedUsers $zncAdminName gets a list of unconfirmed"
                                puthelp "NOTICE $nick :#users."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}ListUnconfirmedUsers"
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}ListUnconfirmedUsers"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick ListUnconfirmedUsers"
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick ListUnconfirmedUsers"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                        confirm {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}Confirm"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}Confirm $zncAdminName can confirm ZNC Account requests."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}Confirm <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                puthelp "NOTICE $nick :#   ${scriptCommandPrefix}Confirm Foo"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#  /msg $botnick Confirm <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick Confirm Foo"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                        deny {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}Deny"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}Deny $zncAdminName can deny ZNC Account requests."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}Deny <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}Deny Foo"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick Deny <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick Deny Foo"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                        deluser {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}DelUser"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}DelUser $zncAdminName can delete ZNC Accounts if they are"
                                puthelp "NOTICE $nick :#already confirmed."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}DelUser <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}DelUser Foo"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick DelUser <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick DelUser Foo"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                        noidle {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}noIdle"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}noIdle $zncAdminName can delete ZNC Accounts if they are idle for more than 15 days"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}noIdle <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}noIdle Foo"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick noIdle <zncusername>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick noIdle Foo"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }

                        chpass {
                                puthelp "NOTICE $nick :#Help for /msg $botnick chpass"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With /msg $botnick chpass, Free-ZNC Admins can change a Free ZNC Account password."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                puthelp "NOTICE $nick :#Syntax:"
                                puthelp "NOTICE $nick :#   /msg $botnick chpass <zncusername> <newpassword>"
                                puthelp "NOTICE $nick :#Example:"
                                puthelp "NOTICE $nick :#   /msg $botnick chpass Foo temPass"

                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick chpass <zncusername> <newpassword>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick chpass Foo temPass"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }

                        addvhost {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}addvhost"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}noIdle $zncAdminName can change the curent host of  ZNC Accounts to a direred new one"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}addvhost <zncusername> <vhost>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}addvhost Foo 10.0.50.3"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick addvhost <zncusername> <vhost>"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick addvhost Foo 10.0.50.3"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }

                        help {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}help"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}help you'll get messages like this one..."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}help \[<command>\]"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}help request"
                                } else {
                                        puthelp "NOTICE $nick :#Syntax:"
                                        puthelp "NOTICE $nick :#   /msg $botnick help \[<command>\]"
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick help request"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                        servers {
                                puthelp "NOTICE $nick :#Help for ${scriptCommandPrefix}servers"
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#With ${scriptCommandPrefix}servers you'll get messages like this one..."
                                puthelp "NOTICE $nick :# "
                                puthelp "NOTICE $nick :#-----------------"
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}servers"
                                } else {
                                        puthelp "NOTICE $nick :#Example:"
                                        puthelp "NOTICE $nick :#   /msg $botnick servers"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                        default {
                                if { $chan != $nick } {
                                        puthelp "NOTICE $nick :#please use ${scriptCommandPrefix}help without parameters for full command list"
                                } else {
                                        puthelp "NOTICE $nick :#please use /msg $botnick help without parameters for full command list"
                                }
                                puthelp "NOTICE $nick :### End of Help ###"
                        }
                }
        } else {
		if {[matchattr $nick YQ]} {
                puthelp "NOTICE $nick :#$scriptname Command list available for ADMINS:"
                puthelp "NOTICE $nick :#${scriptCommandPrefix}request               |Requests an ZNC Account"
       	        puthelp "NOTICE $nick :#${scriptCommandPrefix}ListUnconfirmedUsers  |Lists unconfirmed ZNC Account. \002\00304Requires Admin Rights\003\002."
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}Confirm               |Confirms ZNC Account request. \002\00304Requires Admin Rights\003\002."
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}addvhost              |Change host for ZNC Account. \002\00304Requires Admin Rights\003\002."
               	puthelp "NOTICE $nick :#/msg $botnick chpass        |Change password for ZNC Account. \002\00304Requires Admin Rights\003\002."
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}Deny                  |Denies a ZNC Account request. \002\00304Requires Admin Rights\003\002."
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}DelUser               |Deletes a confirmed ZNC Account. \002\00304Requires Admin Rights\003\002."
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}noIdle                |Deletes a confirmed ZNC Account if the user didn't login for more than 15 days. \002\00304Requires Admin Rights\003\002."
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}lastseen              |Shows the last connection time of the ZNC user. Lastseen module must be enabled on ZNC as admin. \002\00304Requires Admin Rights\003\002."
              	puthelp "NOTICE $nick :#                       |\002\00304!online\003\002 command must be issued before using \002\00304!lastseen\003\002."
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}Online                |Set A Free-ZNC Admin with Status ONLINE. \002\00304Requires Admin Rights\003\002." 
               	puthelp "NOTICE $nick :#${scriptCommandPrefix}Offline               |Set A Free-ZNC Admin with Status OFFLINE. \002\00304Requires Admin Rights\003\002."
                puthelp "NOTICE $nick :#${scriptCommandPrefix}Admins                |Shows current Free-ZNC Admins that are ONLINE"
                puthelp "NOTICE $nick :#${scriptCommandPrefix}help                  |Shows help for commands"
                puthelp "NOTICE $nick :#"
                puthelp "NOTICE $nick :#Use\"${scriptCommandPrefix}help <command>\" for full helpcontext."
                puthelp "NOTICE $nick :#"
                puthelp "NOTICE $nick :#-----------------"
                if { $chan != $nick } {
                        puthelp "NOTICE $nick :#Syntax:"
                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}help \[<command>\]"
                        puthelp "NOTICE $nick :#Example:"
                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}help request"
                } else {
                        puthelp "NOTICE $nick :#Syntax:"
                        puthelp "NOTICE $nick :#   /msg $botnick help \[<command>\]"
                        puthelp "NOTICE $nick :#Example:"
                        puthelp "NOTICE $nick :#   /msg $botnick help request"
                }
                puthelp "NOTICE $nick :### End of Help ###"
        } else {
                puthelp "NOTICE $nick :#$scriptname Command list:"
                puthelp "NOTICE $nick :#${scriptCommandPrefix}request                 |Requests an ZNC Account"
                puthelp "NOTICE $nick :#${scriptCommandPrefix}Admins                  |Shows current Free-ZNC Admins that are ONLINE"
                puthelp "NOTICE $nick :#${scriptCommandPrefix}help                    |Shows help for commands"
                puthelp "NOTICE $nick :#"
                puthelp "NOTICE $nick :#Use\"${scriptCommandPrefix}help <command>\" for full helpcontext."
                puthelp "NOTICE $nick :#"
                puthelp "NOTICE $nick :#-----------------"
                if { $chan != $nick } {
                        puthelp "NOTICE $nick :#Syntax:"
                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}help \[<command>\]"
                        puthelp "NOTICE $nick :#Example:"
                        puthelp "NOTICE $nick :#   ${scriptCommandPrefix}help request"
                } else {
                        puthelp "NOTICE $nick :#Syntax:"
                        puthelp "NOTICE $nick :#   /msg $botnick help \[<command>\]"
                        puthelp "NOTICE $nick :#Example:"
                        puthelp "NOTICE $nick :#   /msg $botnick help request"
                }
                puthelp "NOTICE $nick :### End of Help ###"
     }
   }
}


### ZNC - Functions -----------------------------------------------------------

proc znc:controlpanel:AddNetwork { username network } {
global zncnetworkname
        znc:sendTo:Controlpanel "AddNetwork $username $zncnetworkname"
}

proc znc:controlpanel:AddServer { username network server } {
global zncnetworkname zncircserver zncircserverport
        znc:sendTo:Controlpanel "AddServer $username $zncnetworkname $zncircserver $zncircserverport"
}

proc znc:controlpanel:AddUser { username password } {
        znc:sendTo:Controlpanel "AddUser $username $password"
}

proc znc:controlpanel:DelNetwork { username network } {
        znc:sendTo:Controlpanel "DelNetwork $username $network"
}

proc znc:controlpanel:DelUser { username } {
        znc:sendTo:Controlpanel "DelUser $username"
}

proc znc:lastseen:show { {args "" } } {
        if { $args == ""} {
        znc:sendTo:lastseen "show"
        }
}

proc znc:controlpanel:Disconnect { username network } {
        znc:sendTo:Controlpanel "Disconnect $username $network"
}

proc znc:controlpanel:LoadModule { username modulename {args ""} } {
        if { $args == ""} {
                znc:sendTo:Controlpanel "LoadModule $username $modulename"
        } else {
                znc:sendTo:Controlpanel "LoadModule $username $modulename $args"
        }
}

proc znc:controlpanel:LoadNetModule { username network modulename {args ""} } {
        if { $args == ""} {
                znc:sendTo:Controlpanel "LoadNetModule $username $network $modulename"
        } else {
                znc:sendTo:Controlpanel "LoadNetModule $username $network $modulename $args"
        }
}

proc znc:controlpanel:Reconnect { username zncnetworkname } {
                znc:sendTo:Controlpanel "Reconnect $username $zncnetworkname"
}

proc znc:controlpanel:AddChan { username zncnetworkname zncChannelName } {
                znc:sendTo:Controlpanel "ADDChan $username $zncnetworkname $zncChannelName"
}

proc znc:controlpanel:Set { variable username value } {
        znc:sendTo:Controlpanel "Set $variable $username $value"
}

proc znc:controlpanel:SetChan { variable username network chan value } {
        znc:sendTo:Controlpanel "SetChan $variable $username $network $chan $value"
}

proc znc:controlpanel:SetNetwork { variable username network value } {
        znc:sendTo:Controlpanel "SetNetwork $variable $username $network $value"
}

proc znc:blockuser:block { username } {
        znc:sendTo:blockuser "block $username"
}

proc znc:blockuser:unblock { username } {
        znc:sendTo:blockuser "unblock $username"
}


### Help functions ------------------------------------------------------------
proc znc:helpfunction:generatePassword { secureityLevel passwordLength } {
        set return ""
        if { $secureityLevel >0 } {
        set pool {"1" "2" "3" "4" "5" "6" "7" "8" "9"}
        }
        if { $secureityLevel >1 } {
        lappend pool "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
        }
        if { $secureityLevel >2 } {
        lappend pool "A" "B" "C" "D" "E" "F" "G" "H" "T" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z"
        }
        if { $secureityLevel > 3 } {
        lappend pool "%" "&" "@" "_" "-" "!" "\$" "/" "\\" "." "," ";" "#" "+" "*" "~" "?" "="
        }
        if { $secureityLevel > 4 } {
        lappend pool "??" "??" "??" "??" "??" "??" "??" "<" ">" "|" "??" "??" "??" "??" "??" "??" "??" "??" "???" "??" "??" "??" "??"
        }
        if { $pool == "" } { return }
        for { set i 1 } { $i < $passwordLength } { incr i } {
                set return [string append $return [znc:helpfunction:randelem $pool]]
        }
        return $return
}


### Helpfunction for znc:helpfunction:generatePassword
if {[catch {string append}]} then {
    rename string STRING_ORIGINAL
    proc string {cmd args} {
        switch -regexp -- $cmd {
            ^a(p(p(e(n(d)?)?)?)?)?$ {
                uplevel [list join $args {}]
            }
            default {
                if {[catch {
                    set result [uplevel [list STRING_ORIGINAL $cmd] $args]
                } err]} then {
                    return -code error\
                        [STRING_ORIGINAL map\
                             [list\
                                  STRING_ORIGINAL string\
                                  ": must be bytelength,"\
                                  ": must be append, bytelength,"]\
                             $err]
                } else {
                    set result
                }
            }
        }
    }
 }
###----------------------------------------------------------------------------
proc znc:helpfunction:randelem {list} {
    lindex $list [expr {int(rand()*[llength $list])}]
}

proc znc:helpfunction:loadModuleList { username list } {
    foreach module $list {
                znc:controlpanel:LoadModule $username $module
        }
}

proc znc:helpfunction:loadNetModuleList { username network list} {
    foreach module $list {
                znc:controlpanel:LoadNetModule $username $network $module
        }
}

proc mail:simply:send { usermail subject content } {
        global zncAdminMail
        mail:sendTo:user $zncAdminMail $usermail $subject $content
}

proc mail:simply:send2 { usermail subject content } {
        global zncRequestMail
        mail:sendTo:user2 $zncRequestMail $usermail $subject $content
}

proc mail:simply:sendUserRequest2 { username password vhost } {
        global zncnetworkname znchost zncNonSSLPort zncSSLPort zncWebNonSSLPort zncWebSSLPort zncAdminName zncAdminMail zncRequestMail zncnetworkname
        set email [getuser $username COMMENT]
        set content "Hello!!! \n $username requested a FREE ZNC-Account hosted by $zncnetworkname\n"
        append content \n "ZNC Connection Port is: $zncNonSSLPort"
        append content \n "ZNC Username is: $username"
        append content \n "ZNC requester e-mail address set is: $email"
        append content \n "If all the data is ok please proceed and confirm the request using: !confirm $username , else please deny the request using : !deny $username"
        if { $zncRequestMail != "" } {
        append content \n\n\n\n "If this e-mail is spam please instantly contact $zncAdminMail"
        }
        mail:simply:send $zncRequestMail  "$username Requested ZNC-Account at $zncnetworkname" $content
}


proc mail:simply:sendUserRequest { username password } {
        global zncnetworkname znchost zncNonSSLPort zncSSLPort zncWebNonSSLPort zncWebSSLPort zncAdminName zncAdminMail 
        set email [getuser $username COMMENT]
        set content "Hey $username,\n You've requested a ZNC-Account hosted by $zncnetworkname\n"
        append content \n "Your ZNC Connection Host is: $znchost\n"
        append content \n "Your ZNC Connection Port is: $zncNonSSLPort"
        append content \n "Your ZNC Username is: $username"
        append content \n "Your ZNC Password is: $password"
        append content \n "To connect to your ZNC Client on IRC use /server ${znchost} ${zncNonSSLPort} ${password}"
        append content \n\n "Please Keep in mind that the ZNC account will be automatically DELETED if you DO NOT LOGIN on to your ZNC account for more then 25 DAYS !!!"
        append content \n\n "Thank you and Enjoy $zncnetworkname !!!"
        if { $zncAdminMail != "" } {
        append content \n\n\n\n "If this e-mail is spam please instantly contact $zncAdminMail"
        }
        mail:simply:send $email "Free-ZNC-Account Request at $zncnetworkname" $content
}

proc mail:simply:sendUserRequest3 { username password } {
        global zncnetworkname znchost zncNonSSLPort zncSSLPort zncWebNonSSLPort zncWebSSLPort zncAdminName zncAdminMail zncRequestMail
        set email [getuser $username COMMENT]
        set content "Hello!!! \n $username request for a FREE ZNC-Account hosted by $zncnetworkname was confirmed !!! \n"
        append content \n "ZNC Connection Port is: $zncNonSSLPort"
        append content \n "ZNC Username is: $username"
        append content \n "ZNC password set is: $password"
        append content \n "ZNC requester e-mail address is: $email"
        append content \n\n "An e-mail with login data and instructions was sent also to requester`s e-mail address : $email."
        if { $zncRequestMail != "" } {
        append content \n\n\n\n "If this e-mail is spam please instantly contact $zncAdminMail"
        }
        mail:simply:send $zncRequestMail  "$username Request ZNC-Account at $zncnetworkname was confirmed" $content
}

proc mail:simply:sendUserDeny { username } {
        global zncnetworkname znchost zncNonSSLPort zncSSLPort zncWebNonSSLPort zncWebSSLPort zncAdminName zncAdminMail
        set email [getuser $username COMMENT]
        set content "Hey $username,\n You've requested a ZNC-Account hosted by $zncnetworkname\n"
        append content \n "Your ZNC Request was denyed.\n"
        if { $zncAdminMail != "" } {
        append content \n\n\n\n "If you want to place a complaint regarding this decision please contact $zncAdminMail"
        }
        mail:simply:send $email "ZNC-Account Request Denyed at $zncnetworkname" $content
}

proc mail:simply:sendUserDel { username } {
        global zncnetworkname znchost zncNonSSLPort zncSSLPort zncWebNonSSLPort zncWebSSLPort zncAdminName zncAdminMail
        set email [getuser $username COMMENT]
        set content "Hey $username,\n The request to delete your ZNC-Account hosted by $zncnetworkname is now COMPLETED !!!\n"
        append content \n "Your Free-ZNC account was deleted.\n"
        if { $zncAdminMail != "" } {
        append content \n\n\n\n "If the request didn't came from you or want to place a complaint regarding this action please contact $zncAdminMail"
        }
        mail:simply:send $email "ZNC-Account Deleted at $zncnetworkname" $content
}

proc mail:simply:sendUsernoIdle { username } {
        global zncnetworkname znchost zncNonSSLPort zncSSLPort zncWebNonSSLPort zncWebSSLPort zncAdminName zncAdminMail
        set email [getuser $username COMMENT]
        set content "Hey $username,\n You've requested a ZNC-Account hosted by $zncnetworkname\n"
        append content \n "Your Free-ZNC account was deleted due of inactivity period for more than 15 days.\n"
        if { $zncAdminMail != "" } {
        append content \n\n\n\n "If you want to place a complaint regarding this decision please contact $zncAdminMail"
        }
        mail:simply:send $email "ZNC-Account Deleted at $zncnetworkname" $content
}


proc eggdrop:helpfunction:isNotZNCChannel { chan } {
        return [expr ! [channel get $chan znc]]
}

proc debug:helpfunction:test { nick host handle text } {
	global zncChannelName
        puthelp "PRIVMSG $nick :Channels: [join [channels] ,]"
        puthelp "PRIVMSG $nick :[eggdrop:helpfunction:isNotZNCChannel "$zncChannelName" ]"
}

proc debug:helpfunction:testchan { nick host handle chan text } {
        global zncPasswordSecurityLevel zncPasswordLength
        puthelp "PRIVMSG $nick :$chan"
        puthelp "PRIVMSG $nick :[znc:helpfunction:generatePassword  $zncPasswordSecurityLevel $zncPasswordLength ]"
}

### sendTo - Functions --------------------------------------------------------
proc znc:sendTo:Controlpanel { command } {
        global zncprefix
        putquick "PRIVMSG ${zncprefix}controlpanel :$command"
}

proc znc:sendTo:lastseen { command } {
        global zncprefix
        putquick "PRIVMSG ${zncprefix}lastseen :$command"
}

proc znc:sendTo:blockuser { command } {

        global zncprefix
        putquick "PRIVMSG ${zncprefix}blockuser :$command"
}

proc znc:sendTo:user { command } {
        global user
        putquick "PRIVMSG $nick :To Connect to ZNC-Server use \"${username}:${password}\" as server-password"
}



### Commands - Functions ------------------------------------------------------

## Request Commands
proc znc:PUB:request {requester host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:request $requester $host $handle $chan $text
}

proc znc:MSG:request {nick host handle text} {
        znc:request $nick $host $handle $nick $text $requester
}

## Confirm Commands
proc znc:PUB:confirm {requester host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:confirm $requester $host $handle $chan $text
}

proc znc:MSG:confirm { requester nick host handle text} {
        znc:confirm $requester $nick $host $handle $nick $text
}

## AddVhost Commands
proc znc:PUB:addvhost {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:addvhost $nick $host $handle $chan $text
}

proc znc:MSG:addvhost {nick host handle text} {
        znc:addvhost $nick $host $handle $chan $text
}

## chpass Commands
proc znc:PUB:chpass {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:chpass $nick $host $handle $chan $text
}

proc znc:MSG:chpass {nick host handle text} {
        znc:chpass $nick $host $handle $text
}

## Deny Commands
proc znc:PUB:deny {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:deny $nick $host $handle $chan $text
}

proc znc:MSG:deny {nick host handle text} {
        znc:deny $nick $host $handle $nick $text
}

## DelUser Commands
proc znc:PUB:delUser {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:delUser $nick $host $handle $chan $text
}

## noIdle Commands
proc znc:PUB:noIdle {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:noIdle $nick $host $handle $chan $text
}

proc znc:PUB:lastseen {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:lastseen $nick $host $handle $chan $text
}

proc znc:MSG:noIdle {nick host handle text} {
        znc:noIdle $nick $host $handle $nick $text
}

## ListUnconfirmedUsers Commands
proc znc:PUB:listUnconfirmed {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:listUnconfirmed $nick $host $handle $chan $text
}

proc znc:MSG:listUnconfirmed {nick host handle text} {
        znc:listUnconfirmed $nick $host $handle $nick $text
}

## Admins Command
proc znc:PUB:Admins {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:Admins $nick $host $handle $chan $text
}

## Online Command

proc znc:PUB:Online {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:Online $nick $host $handle $chan $text
}

## OFFLINE Command
proc znc:PUB:Offline {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:Offline $nick $host $handle $chan $text
}


## Help Commands
proc znc:PUB:help {nick host handle chan text} {
        if [eggdrop:helpfunction:isNotZNCChannel $chan ] { return }
        znc:help $nick $host $handle $chan $text
}

proc znc:MSG:help {nick host handle text} {
        znc:help $nick $host $handle $nick $text
}

proc znc:chatproc {nick host handle text} {
global botnick zncChannelName  requestlastseen
set bots [bots]
 if {[string match -nocase "*lastseen" $nick] } {
	foreach u [userlist A] {
	set nick2 [hand2nick $u]
         putserv "NOTICE $nick2 :\002\[\002$text\002\]\002"
	}
    }
}

proc joinnotice {noticenick noticehost noticehandle noticechan} {
global zncChannelName zncnetworkname
 if { $noticechan == $::zncChannelName } {
   putserv "NOTICE $noticenick :Welcome To $zncChannelName on $zncnetworkname Network."
   putserv "NOTICE $noticenick :Please type \002\00304!request\003\002 in order to request a free-znc !"
   putserv "NOTICE $noticenick :Free-ZNC Admins will gladly help you if needed. To check if an admin is ONLINE, please type \002\00304!admins\003\002 command in $zncChannelName."
   putserv "NOTICE $noticenick :Thank you for joining $zncnetworkname Network. Enjoy your stay in here!"
    }
}



proc status:cmd {nick host hand chan arg} {
global zncircserverport
        set ip [lindex [split $arg] 0]
if {$ip == ""} {
        putserv "NOTICE $nick :Foloseste !check <vhost>"
        return
}
        set to_much 0
        set ips ""
        set ips_out ""
        set out [exec netstat -antu | grep :$zncircserverport | grep -v LISTEN | tr -s " " | cut -d " " -f5 | cut -d: -f1 | sort | uniq -c]
        set split_out [split [concat $out] "\n"]
        set c 0
foreach i $split_out {
        set line [concat $i]
        set split_i [split $line " "]
        set nr [lindex $split_i 0]
        set the_ip [lindex $split_i 1]
if {[string match -nocase $ip $the_ip]} {
if {$nr > 2} {
        set to_much 1
        break
                }
        lappend ips_out "\#$nr $the_ip"
        }
#       putlog $ips_out
}
if {$to_much == "1"} {
        putserv "NOTICE $nick :$the_ip are deja 3 conexiuni, te rog alege alt vhost"
        return
        }
if {$ips_out == ""} {
        putserv "NOTICE $nick :Pentru $ip nu am gasit nicio conexiune."
        return
        }
#       putserv "NOTICE $nick :[join $ips_out ", "]"
        putserv "NOTICE $nick :$ip are $nr conexiuni."
}


### custom flags --------------------------------------------------------------

## ZNC Channel flag
setudef flag znc


### binds ---------------------------------------------------------------------

## public binds ---------------------------------------------------------------
bind PUB - "${scriptCommandPrefix}Request" znc:PUB:request
bind PUB Y "${scriptCommandPrefix}Confirm" znc:PUB:confirm
bind PUB Y "${scriptCommandPrefix}AddVhost" znc:PUB:addvhost
bind PUB Q "${scriptCommandPrefix}chpass" znc:PUB:chpass
bind PUB Y "${scriptCommandPrefix}Deny" znc:PUB:deny
bind PUB Y "${scriptCommandPrefix}DelUser" znc:PUB:delUser
bind PUB Y "${scriptCommandPrefix}noIdle" znc:PUB:noIdle
bind PUB Y "${scriptCommandPrefix}lastseen" znc:PUB:lastseen
bind PUB Y "${scriptCommandPrefix}ListUnconfirmedUsers" znc:PUB:listUnconfirmed
bind PUB Y "${scriptCommandPrefix}LUU" znc:PUB:listUnconfirmed
bind PUB - "${scriptCommandPrefix}Admins" znc:PUB:Admins
bind PUB YQ "${scriptCommandPrefix}Online" znc:PUB:Online
bind PUB YQ "${scriptCommandPrefix}Offline" znc:PUB:Offline
bind PUB - "${scriptCommandPrefix}help" znc:PUB:help
bind msgm f * znc:chatproc
bind join -|- * joinnotice
bind pub - !check status:cmd

## private binds --------------------------------------------------------------
bind MSG - "Request" znc:MSG:request
bind MSG Y "Confirm" znc:MSG:confirm
bind MSG Y "AddVhost" znc:MSG:addvhost
bind MSG Q "chpass" znc:MSG:chpass
bind MSG Y "Deny" znc:MSG:deny
bind MSG Y "DelUser" znc:MSG:delUser
bind MSG Y "noIdle" znc:MSG:noIdle
bind MSG Y "ListUnconfirmedUsers" znc:MSG:listUnconfirmed
bind MSG Y "LUU" znc:MSG:listUnconfirmed
bind MSG - "help" znc:MSG:help

## debug binds ----------------------------------------------------------------
if {$scriptdebug} {
        bind PUB n "!test" debug:helpfunction:testchan
        bind MSG n "test" debug:helpfunction:test
}


### End of Script -------------------------------------------------------------
putlog "$scriptname version $scriptversion and upgraded to $scriptversionUpdated by $scriptUpdater loaded"


