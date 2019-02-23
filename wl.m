global am=[0
5
10
15
20
25
30
35
40
45
50
55
60
65
70
75
80
85
90
];
global wm=[
0
0.202808524
0.431141736
0.688212075
0.977636283
1.303486291
1.670346508
2.083378319
2.5483927
3.071931975
3.661361859
4.324975085
5.07210808
5.913272315
6.860302195
7.926521557
9.126931123
10.47841955
12.00000103
];
function y = tf(x,p)
  y=p(2)*(1-1/(x*p(1)+1))+x*p(3);
endfunction  
function s = pf(p)
  global wm;
  global am;
  s=0;
  for i=1:19
    y=tf(wm(i),p);
    d=y-am(i);
    d2=d*d;
    s=s+d2;
  endfor;
endfunction

sol=fminsearch(@(x) pf(x),[1,1,1])
pen=pf(sol)
vrf=[0,0;0,0];
for i=1:19
  vrf(i,1)=wm(i);
  vrf(i,2)=am(i);
  vrf(i,3)=tf(wm(i),sol);
endfor
vrf