Performance comparison:  
|                 | serial (no AVX) | AVX    |
|:---------------:| :-------------: | :----: |
|MSVC 2019 (/O2)  | 0.28 s          | 0.19 s |
|Assembly         | 0.44 s          | 0.205 s|
|Assembly gain    | 157%            | 7.89%  |
