# zotero-find
#### Emacs package to lookup and open items from a Zotero database
The code in this package was taken and adopted from the calibre-mode package found at https://github.com/whacked/calibre-mode. For now it simply **searches for a match of a single given query in the titles and author names of the parent items** in the given Zotero database. **Items without parent items are not found** by the sql query in this package. Except for the code required for the zotero-find function, the code is dysfunctional (but kept here for possibility of updating/extending the package).

## Warnings!!
This package can not be used when an instance of Zotero is running as Zotero then locks the database (so more precisely, Zotero and this package can not use the same database simultaneously).
It looks like the package does not really work well if Zotero is not used to store the files locally (in the Zotero/storage subfolder).
Although the package seems to work fine with both Ivy and Helm, I don't know how/if it works without any of these packages installed.

*Although I expect this package to just work on most systems, it is not yet tested on other systems than my own. If there is some problem then please message me or open an issue* 
## Install

Install in the usual way and set the `zotero-root-dir` variable either via setq in your dot-file or via the customization menu.
The package uses Ivy for fuzzy searching/selecting the results of the initial query. Although the package can be used without Ivy, installing Ivy strongly enhances the functionality.

### Spacemacs
For spacemacs users the recommended way is to clone this repository in your `.emacs.d/private/local` directory.<sup id="a1">[1](#f1)</sup> Then add it to the load-path by adding `(zotero-find :location local)` to the list of additional packages. Subsequently load it by adding the following use-package (or use require) declaration in the user-config section of your dot-file:
```
  (use-package zotero-find
    :init
    (setq zotero-root-dir "/path/to/directory/Zotero/"))
```
or on linux if your Zotero directory is located at it's default location `~/Zotero/` then just add `(use-package zotero-find)`

<b id="f1">1</b> You might want to keep your private directory in a (cloud) synced directory, and create a symlink to that directory from your .emacs.d directory. [↩](#a1)

## Usage
Use `M-x zotero find`, after selecting a match press small `o` to open file in current frame.

### Spacemacs
Use `SPC SPC zotero-find`, after selecting a match press small `o` to open file in current frame.

You might want to add a shortcut under `SPC SPC a z` by placing `(spacemacs/set-leader-keys "az" 'zotero-find)` in the user- config section of your dot-file

email: dalanicolai@gmail.com
