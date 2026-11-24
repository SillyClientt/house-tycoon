import re, sys, glob
def strip(src):
    out=[]; i=0; n=len(src)
    while i<n:
        if src.startswith('--[[',i) or src.startswith('--[=[',i):
            close = ']]' if src.startswith('--[[',i) else ']=]'; j=src.find(close,i); i = n if j<0 else j+len(close); continue
        if src.startswith('--',i):
            j=src.find('\n',i); i = n if j<0 else j; continue
        c=src[i]
        if c in '"\'`':
            j=i+1
            while j<n and src[j]!=c:
                if src[j]=='\\': j+=1
                if src[j]=='\n' and c!='`': raise SyntaxError(f'unterminated string at {i}')
                j+=1
            out.append(' S '); i=j+1; continue
        if src.startswith('[[',i):
            j=src.find(']]',i); out.append(' S '); i=j+2; continue
        out.append(c); i+=1
    return ''.join(out)
bad=0
for p in sorted(glob.glob('project/src/**/*.lua', recursive=True)):
    if 'Packages' in p: continue
    s=strip(open(p).read())
    depth=0; problems=[]
    for ln,line in enumerate(s.split('\n'),1):
        toks=re.findall(r'[A-Za-z_]\w*',line)
        first = toks[0] if toks else ''
        for k,t in enumerate(toks):
            if t=='function': depth+=1
            elif t=='do': depth+=1
            elif t=='repeat': depth+=1
            elif t=='if' and k==0: depth+=1
            elif t=='end': depth-=1
            elif t=='until': depth-=1
        if depth<0: problems.append(ln); depth=0
    parens = s.count('(')-s.count(')'); braces=s.count('{')-s.count('}'); brackets=s.count('[')-s.count(']')
    status = 'OK' if depth==0 and not problems and parens==0 and braces==0 and brackets==0 else f'CHECK depth={depth} neg={problems[:3]} () {parens} {{}} {braces} [] {brackets}'
    if status!='OK': bad+=1
    print(f'{status:8} {p.replace("project/src/","")}')
print('files with issues:', bad)
