# 📬 mdstat knows things about your MailDirs

mdstat lists unread MailDirs under a given path. That's it.


# Usage

```
mdstat ~/mail
=Inbox =Junk =ml/hackers =ml/hackers/kitchen
```

mdstat explodes the Maildir tree: if you file your wood-working news to
`=news/wood-working`, then mdstat will list two directories: `=news` and
`=news/wood-working`, even if `=news` doesn't contain unread emails.

Why? This makes mdstat a suitable command for (neo)mutt's
`sidebar_whitelist` to display a *complete* tree down to unread
directories ; or simply to get a list of unread maildirs in a status
program.


# Building

You need [zig] to build this.

```
git clone https://git.cypr.io/oz/mdstat.git
cd mdstat
zig build -Drelease-safe=true
```

This should produce the mdstat binary at: `./zig-out/bin/mdstat`

# Testing

YOLO.


# License

The GPL3 license.

Copyright (c) 2022 Arnaud Berthomier
