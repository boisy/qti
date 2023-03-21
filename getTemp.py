import subprocess
result = subprocess.run(['./directtemp'], stdout=subprocess.PIPE)
print(result.stdout.decode('utf-8'))