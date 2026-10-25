"""Independent calendar expectations from reference JSON and docs 11/13/15.

Python integer arithmetic, not the Luau resolver under test. No production imports.
"""
from pathlib import Path
import argparse, hashlib, json
ROOT=Path(__file__).resolve().parents[2]
CYCLES=[0,1,2,3,5,7,9,23,24,66]
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
 source=ROOT/'docs/reference_data/rewards.json';rows=json.loads(source.read_text(encoding='utf-8'))['calendar']
 types={0:'GE',2:'Cash',4:'SE',5:'PE',6:'Epic',7:'Piggy',9:'PiggyLevel',10:'Boost',14:'ShellScripts'}
 cases=[]
 for m in CYCLES:
  rewards=[]
  for row in rows:
   values=[int(x) for x in row['rewardValues']];subtypes=row['subtypes'];mode=row['scalingMode']
   assert all(int(x)==x for x in row['rewardValues'])
   if mode==0:amount=values[min(m,len(values)-1)];subtype=subtypes[min(m,len(subtypes)-1)]
   elif mode==1:amount=values[0];subtype=subtypes[m%len(subtypes)]
   elif mode==2:amount=min(int(row['cap']),values[0]*(m+1));subtype=subtypes[0]
   else:
    assert mode==3;amount=min(int(row['cap']),values[0]*(1<<m));subtype=subtypes[0]
   kind=types[row['type']]
   if row['day']==28 and m>=24:kind='GE';amount=100000
   rewards.append({'day':row['day'],'kind':kind,'amount':amount,'subtype':subtype})
  cases.append({'cycle':m,'rewards':rewards})
 # Independent documented totals, guarding interpretation and indexing of the oracle.
 first=cases[0]['rewards']
 assert sum(x['amount'] for x in first if x['kind']=='GE')==4372
 assert sum(x['amount'] for x in first if x['kind']=='SE')==140000
 assert sum(x['amount'] for x in first if x['kind']=='Piggy')==15000
 assert sum(x['amount'] for x in first if x['kind']=='ShellScripts')==15
 result={'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'cases':cases}
 text=json.dumps(result,indent=2)+'\n';target=ROOT/'tests/calendar_cycle/oracle.json'
 if args.check:assert target.read_text(encoding='utf-8')==text,'Calendar oracle is stale'
 else:target.write_text(text,encoding='utf-8')
 print(f'Independent calendar oracle: {len(cases)*28} reward rows PASS')
if __name__=='__main__':main()
