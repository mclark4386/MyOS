# MyOS
Playing with making an OS


# Prereqs

Make, NASM, mtools, dosfstools, and QEMU
bochs for debugging

# To run 

`make && qemu-system-i386 -fda build/main_floppy.img` in the root of the project


### LBA to CHS conversions

`sector = (LBA % sectors per track) + 1`
`head = (LBA / sectors per track) % heads`
`cylinder = (LBA / sectors per track) / heads`
