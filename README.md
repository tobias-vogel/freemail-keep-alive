# freemail-keep-alive
A ruby tool to prevent your freemail accounts from expiring due to being unused


## Purpose
I had the problem of occasionally using several freemail accounts for several purposes, for example, my Amazon purchases.
I have set all of them to forward any email to my "real" email account. Thus, I don't ignore their messages, but unfortunately, forwarding emails from these accounts do not count as usage and therefore, these accounts get deleted. Even worse, the expiry warning did not come through/were not forwarded to my "real" email account.

One solution could have been to set up my "real" email account to fetch emails from those accounts, but first, the number of accounts I can fetch with that mechanism might be (and actually is) limited and second, I'd have to provide the credentials to my "real" email account provider.

I therefore thrived for a solution for that expiry problem and to circumvent the need of providing the credentials to my email provider. The result is that neat Ruby tool which can be run as a cron job, for example.


## Capabilities (and ToDos)
Currently implemented features:
* Log in and keep the accounts alive
* Discover the email account settings automatically from Mozilla's ISP database

Features that might be implemented later:
* Forward (new and unread) emails (with attachments) to my specified "real" email account
* Send a digest/error/report message to my "real" email account when appropriate (regularly, upon errors)


## Installation and Configuration
You will obviously need Ruby (1.9.x or later). You will further need the gems "mail" (for email capabilities) and "httpclient" (for proper HTTPS support).

Clone this repository. The configuration directory contains the TSV file you have to fill with your account credentials. For not to accidentally commit them, you should remove this file from being tracked by git. Issue the following command:
git update-index --skip-worktree configuration/accounts.tsv

Then, run it by just issueing:
ruby freemail-keep-alive.rb


## Powered by
This tool bases on some Stack Overflow threads and the mail gem by mikel.
https://github.com/mikel/mail
http://www.rubydoc.info/gems/mail/frames