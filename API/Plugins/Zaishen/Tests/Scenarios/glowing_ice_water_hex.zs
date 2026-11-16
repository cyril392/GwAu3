# Glowing Ice: energy only from a foe under a water hex. Our Deep Freeze is on #11 (the hex flag alone is on #10).
M|now=1000|ping=80|myid=1|energy=10|maxenergy=40
S|1|2192          # Glowing Ice
S|2|234|0|20000   # Deep Freeze, recharging
A|1|0|0|1|480|0|ally|player|0|0|6
A|10|500|0|1|0|0|foe|hexed
A|11|800|0|1|0|0|foe|hexed
R|234|11|6000
E|action=skill|slot=1|target=11
