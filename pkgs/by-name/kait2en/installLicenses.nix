# Upstream's GPL-3.0-or-later components add an attribution term under section
# 7(b), so ship its notices the way upstream's own packaging does.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/LICENSING.md
{ }:
pname: ''
  install -Dm444 -t "$out/share/licenses/${pname}" \
    LICENSE LICENSING.md LICENSES/GPL-3.0-or-later.txt
''
