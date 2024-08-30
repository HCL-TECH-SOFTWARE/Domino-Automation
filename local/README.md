Put your **custom files** you want to use for Domino server setup into this directory.

It is recommended to separate files into subdirectories, one for each Domino domain.

For storing Notes ID files please use a dedicated subdirectory: `ids`.

Example (for the Domino domain "Example"):
  - local/example/ids/*.id
  - local/example/keys/
  - local/example/users.csv
  - local/example/weblogin.nsf
