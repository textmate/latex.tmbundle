#!/usr/bin/env python

import sys
import os
import re
#TODO: modify this script to produce opml
#Parse current document or TM_LATEX_MASTER to find \usepackage statements
#Create a special section of my packages

if os.environ.get("TM_LATEX_MASTER",None):
    myFile = open(os.environ["TM_LATEX_MASTER"],'r')
else:
    myFile = open(os.environ["TM_FILEPATH"],'r')
mList = []
packMatch = re.compile(r"^\\usepackage(\[.*\])?\{(\w+)\}")
for line in myFile:
    g = packMatch.match(line)
    if g:
        mList.append(g.group(2))


texMFbase = os.environ["TM_LATEX_DOCBASE"]
docIndex = texMFbase + "texdoctk/texdoctk.dat"
docBase = texMFbase + "doc/"
catalogDir = os.environ["TM_LATEX_HELP_CATALOG"]

pathDict = {}
descDict = {}
headings = {}

docIndexFile = open(docIndex,'r')
for line in docIndexFile:
    if line[0] == "#":
        continue
    elif line[0] == "@":
        currentHeading = line[1:].strip()
        headings[currentHeading] = []
    else:
        try:
            key,desc,path,cats = line.split(';')
        except:
            key,desc,path = line.split(';')
        headings[currentHeading].append(key)
        if path.rfind('.sty') >= 0:
            path = texMFbase + "tex/" + path
        else:
            path = docBase + path
        pathDict[key] = path.strip()
        descDict[key] = desc.strip()

# supplement texdoctk index with the regular texdoc catalog
for fname in os.listdir(catalogDir):
    key = fname[:fname.rfind('.html')]
    if key not in pathDict:
        pathDict[key] = catalogDir + fname
        descDict[key] = key
        
cwPackage = os.environ.get("TM_CURRENT_WORD",None)
if cwPackage in pathDict:
    os.system("open " + pathDict[cwPackage])
    sys.exit()

print """
<style type="text/css"><!--
.save{
   behavior:url(#default#savehistory);}
a.dsphead{
   text-decoration:none;
   margin-left:1.5em;}
a.dsphead:hover{
   text-decoration:underline;}
a.dsphead span.dspchar{
   font-family:monospace;
   font-weight:normal;}
.dspcont{
   display:none;
   margin: 0px 20px 0px 20px;}
//--></style>


<script type="text/javascript"><!--
function dsp(loc){
   if(document.getElementById){
      foc=loc.parentNode.nextSibling.style?
         loc.parentNode.nextSibling:
         loc.parentNode.nextSibling.nextSibling;
      foc.style.display=foc.style.display=='block'?'none':'block';}}  

//-->
</script>
"""    
print "<h1>Your Packages</h1>"
print "<ul>"
for p in mList:
    if p in pathDict:
        print """<li><a href="javascript:TextMate.system('open %s', null);">%s</a>
             </li> """%(pathDict[p],descDict[p])
    else:
        print """<li>%s</li>"""%(p)
print "</ul>"

print "<hr />"
print "<h1>Packages Browser</h1>"
print "<ul>"
for h in headings:
    print '<li><a href="javascript:dsp(this)" class="dsphead" onclick="dsp(this)">%s</a></li>'%(h)
    print '<div class="dspcont">'
    print "<ul>"
    for p in headings[h]:
        print """<li><a href="javascript:TextMate.system('open %s', null);">%s</a>
             </li> """%(pathDict[p],descDict[p])
    print "</ul>"
    print '</div>'
print "</ul>"

