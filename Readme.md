# Description
This project contains 2 programs that blur BMP images (box blur algorithm). One is written in Assembly, the other one is written in C++ with /O2 optimization level.

Performance comparison:  
|                 | serial (no AVX) | AVX    |
|:---------------:| :-------------: | :----: |
|MSVC 2019 (/O2)  | 0.28 s          | 0.19 s |
|Assembly         | 0.44 s          | 0.205 s|
|Assembly gain    | +57%            | +7.89%  |
