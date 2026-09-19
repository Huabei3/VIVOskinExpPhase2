# -*- coding: utf-8 -*-
"""临时脚本：连接云实例查看目录结构，用完即删。"""
import paramiko

HOST = 'connect.westc.seetacloud.com'
PORT = 41087
USER = 'root'
PWD = 'RsNhjio5oaa8'


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PWD, timeout=30)
    return c


def run(c, cmd):
    i, o, e = c.exec_command(cmd)
    return o.read().decode('utf-8', 'replace'), e.read().decode('utf-8', 'replace')


if __name__ == '__main__':
    c = connect()
    cmds = [
        'echo "===== conda envs ====="; ls /root/miniconda3/envs 2>&1',
        'echo "===== deepskin python/torch ====="; /root/miniconda3/envs/deepskin/bin/python -c "import sys; print(sys.version)" 2>&1; /root/miniconda3/envs/deepskin/bin/python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.device_count())" 2>&1',
        'echo "===== pip packages (skimage/scipy/pandas/openpyxl/numpy) ====="; /root/miniconda3/envs/deepskin/bin/python -c "import numpy,scipy,skimage,pandas,openpyxl; print(numpy.__version__, scipy.__version__, skimage.__version__, pandas.__version__)" 2>&1',
        'echo "===== display_model ====="; ls -la /root/autodl-tmp/render_code/A_characterization/display_model 2>&1',
        'echo "===== I_render_stimuli_python (again) ====="; ls -la /root/autodl-tmp/render_code/I_render_stimuli_python 2>&1',
        'echo "===== original_image_XYZ on cloud ====="; find /root/autodl-tmp -maxdepth 3 -iname "*XYZ*" 2>/dev/null',
        'echo "===== root disk usage ====="; df -h /root 2>&1',
    ]
    for cmd in cmds:
        out, err = run(c, cmd)
        print(out)
        if err.strip():
            print('[ERR]', err)
    c.close()
