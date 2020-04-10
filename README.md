# zotero-find

## Install

Install in the usual way and set the `zotero-root-dir` variable either via setq in your dot-file or via the customization menu.

### Spacemacs

For spacemacs users the recommended way is to clone this repository in your `.emacs.d/private/local` directory.<sup id="a1">[1](#f1)</sup> Then add it to the load-path by adding `(use-package zotero-find)` to the list of additional packages. Subsequently load it by adding the following use-package (or use require) declaration in the user-config section of your dot-file: 
```
  (use-package zotero-find
    :init
    (setq zotero-root-dir "/mnt/4EEDC07F44412A81/Zotero/")).
```

<b id="f1">1</b> You might want to keep your private directory in a (cloud) synced directory, and create a symlink to that directory from your .emacs.d directory. [↩](#a1)
