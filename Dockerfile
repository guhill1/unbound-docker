#13 [builder  4/22] RUN git config --global credential.helper '!f() { :; }; f' &&     git clone git@github.com:nghttp2/nghttp3.git || { echo "git clone nghttp3 failed"; exit 1; }
#13 0.139 Cloning into 'nghttp3'...
#13 0.216 Host key verification failed.
#13 0.217 fatal: Could not read from remote repository.
#13 0.217 
#13 0.217 Please make sure you have the correct access rights
#13 0.217 and the repository exists.
#13 0.218 git clone nghttp3 failed
#13 ERROR: process "/bin/sh -c git config --global credential.helper '!f() { :; }; f' &&     git clone git@github.com:nghttp2/nghttp3.git || { echo \"git clone nghttp3 failed\"; exit 1; }" did not complete successfully: exit code: 1
------
 > [builder  4/22] RUN git config --global credential.helper '!f() { :; }; f' &&     git clone git@github.com:nghttp2/nghttp3.git || { echo "git clone nghttp3 failed"; exit 1; }:
0.139 Cloning into 'nghttp3'...
0.216 Host key verification failed.
0.217 fatal: Could not read from remote repository.
0.217 
0.217 Please make sure you have the correct access rights
0.217 and the repository exists.
0.218 git clone nghttp3 failed
------
Dockerfile:31
--------------------
  30 |     # 1. 克隆仓库（使用SSH协议）
  31 | >>> RUN git config --global credential.helper '!f() { :; }; f' && \
  32 | >>>     git clone git@github.com:nghttp2/nghttp3.git || { echo "git clone nghttp3 failed"; exit 1; }
  33 |     
--------------------
ERROR: failed to solve: process "/bin/sh -c git config --global credential.helper '!f() { :; }; f' &&     git clone git@github.com:nghttp2/nghttp3.git || { echo \"git clone nghttp3 failed\"; exit 1; }" did not complete successfully: exit code: 1
Error: Process completed with exit code 1.
