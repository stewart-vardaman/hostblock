#!/bin/sh

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Script to combine Black's and Yoyo's ad block list, format it so:

#   A) Remove "www*." names that will already be blocked by TLDs.
#   B) De-dupe and optimize hosts/dns files to bare minimum.
#   C) DNS for DNSMasq, hosts for Linux/Windows/Mac/Android.

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# As of Dec 13th 2017, yoyo has 13 hosts that the other block
# lists don't (adotmob.com for example). For now, add yoyo.

 wget -O yoyo.txt \
    --no-check-certificate \
    https://pgl.yoyo.org/as/serverlist.php?showintro=0
grep -E "127.0.0.1 " yoyo.txt | \
  sed 's/127.0.0.1 /0.0.0.0 /g' \
  > ctmp.txt

 wget -O black.txt \
   --no-check-certificate \
   https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

grep -E -v "0.0.0.0 0.0.0.0" black.txt | \
  grep -E "0.0.0.0 " \
  >> ctmp.txt

# Manual TLDs are blocks not yet at full TLD, but appear to
# be only ads. Also any manual blocks I decide.
awk '{print "0.0.0.0 " $1}' manual-tlds.txt >> ctmp.txt
sed -i -e 's/#.*$//' -e '/^$/d' ctmp.txt
dos2unix ctmp.txt
sort -u ctmp.txt > combined.txt
rm -rf ctmp.txt

sed -e 's/0.0.0.0 www[0-9]\./0.0.0.0 /g' \
    -e 's/0.0.0.0 www[0-9][0-9]\./0.0.0.0 /g' \
    -e 's/0.0.0.0 www[0-9][0-9][0-9]\./0.0.0.0 /g' \
    -e 's/0.0.0.0 ww[0-9]\./0.0.0.0 /g' \
    -e 's/0.0.0.0 ww[0-9][0-9]\./0.0.0.0 /g' \
    -e 's/0.0.0.0 ww[0-9][0-9][0-9]\./0.0.0.0 /g' \
    -e 's/0.0.0.0 www\./0.0.0.0 /g' combined.txt | \
  awk '{print $2}' | \
  sort -u > final-hosts.txt

# Find all TLDs. They will only have a single "." in their host name.
rm -rf tmptld.txt
x=0
while read line; do
  numdots=$(echo $line | grep --only-matching "\." | grep --count "\.")
  if [ $numdots = 1 ]; then
    x=$(($x + 1))
    echo "TLD count = $x   ---   TLD line is $line"
    echo $line >> tmptld.txt
  fi
done < final-hosts.txt

sort -u tmptld.txt > tld.txt
rm -rf tmptld.txt

# This removes any TLDs found in the 'single dot' loop above and removes them.
grep -vwF -f tld.txt final-hosts.txt > tmp.txt

# Final for DNSMasq, combo of subdomains and TLDs, no dupes
cat tld.txt tmp.txt | sort -u > final-dns.txt
rm -rf tmp.txt

# Make hosts file
cat header.txt > hosts.txt
awk '{print "0.0.0.0 " $1}' final-hosts.txt >> hosts.txt

# Make DNSMasq address block list
awk '{print "address=/" $1 "/0.0.0.0"}' final-dns.txt > /etc/dnsmasq.d/blocklist.conf
sudo service dnsmasq restart

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

echo "\r\n\r\nDone with script!\r\n\r\n"
