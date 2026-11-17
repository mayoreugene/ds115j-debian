ds115j.dts — current board device-tree source.
ds115j.dtb — matching compiled DTB, appended to boot/uImage-ds115j.

Use the source and DTB as a pair. The historical
ds115j.dts.stale-with-alarm-gpios file is retained for reference only; do not
build or boot it. Its alarm-gpios node caused a udev storm.
