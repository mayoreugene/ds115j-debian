ds115j.dts — current board device tree source; no alarm-gpios.
ds115j.dtb — matching compiled DTB, appended to boot/uImage-ds115j.

Use the source and DTB as a pair. The obsolete alarm-gpios source was removed;
it caused a udev storm and must not be reintroduced.
