# zotero-find
The code in this package was taken and adopted from the calibre-mode package found at https://github.com/whacked/calibre-mode. For now it simply **searches for a match of a single given query in the titles and author names of the parent items** in the given Zotero database. **Items without parent items are not found** by the sql query in this package. Except for the code required for the zotero-find function, the code is dysfunctional (but kept here for possibility of updating/extending the package).


## Install
Install in the usual way and set the `zotero-root-dir` variable either via setq in your dot-file or via the customization menu

### Spacemacs
For spacemacs users the recommended way is to clone this repository in your `.emacs.d/private/local` directory.<sup id="a1">[1](#f1)</sup> Then add it to the load-path by adding `(use-package zotero-find)` to the list of additional packages. Subsequently load it by adding the following use-package (or use require) declaration in the user-config section of your dot-file: 
```
  (use-package zotero-find
    :init
    (setq zotero-root-dir "/path/to/directory/Zotero/"))
```

<b id="f1">1</b> You might want to keep your private directory in a (cloud) synced directory, and create a symlink to that directory from your .emacs.d directory. [↩](#a1)

## Usage
Use `M-x zotero find`, after selecting a match press small `o` to open file in current frame.

### Spacemacs
Use `SPC SPC zotero-find`, after selecting a match press small `o` to open file in current frame.

You might want to add a shortcut under `SPC SPC a z` by placing `(spacemacs/set-leader-keys "az" 'zotero-find)` in the user- config section of your dot-file
