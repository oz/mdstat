# 📬 mdstat knows things about your MailDirs

mdstat lists MailDirs under a given path. That's it.


# Usage

List all MailDirs under a given tree:

```
mdstat ~/mail
="Inbox" ="Junk" ="ml/hackers/kitchen"
```

That works well as a `mailboxes` command for mutt or neomutt if you
don't want to handwrite that list, or keep a cache. On an old laptop
(2016), mdstat takes around 13ms to go through a 30k nodes tree ; so I
can't notice it.

List only unread MailDirs with `-u`:

```
mdstat ~/mail -u
="Inbox" ="ml" ="ml/hackers" ="ml/hackers/kitchen"
```

This signals unread emails under `Inbox` and `ml/hackers/kitchen`
folders: mdstat with `-u` explodes the Maildir tree.

Example: if you filed your wood-working news to `=news/wood-working`,
then `mdstat -u` would list two directories: `=news` and
`=news/wood-working`, *even if `=news` doesn't contain unread emails*.

Why? This makes mdstat a suitable command for mutt's `sidebar_whitelist`
to display a *complete* tree down to unread directories which mutt can't
do for reasons. This "expansion" only works if your directory separator
is `/` because I don't care about other separators, yet.

# Building

You need [zig] 0.12 to build this.

```
git clone https://git.cypr.io/oz/mdstat.git
cd mdstat
zig build -Doptimize=ReleaseSafe
```

This should produce the mdstat binary at: `./zig-out/bin/mdstat`

# Testing

YOLO.

# Bugs

This program has bugs. If you find one, you can report it to `oz [@]
cyprio.net`, or through the [issue
tracker](https://git.cypr.io/oz/mdstat/issues).

# License

The GPL3 license.

Copyright (c) 2022-2023 Arnaud Berthomier

[zig]: https://ziglang.org/
