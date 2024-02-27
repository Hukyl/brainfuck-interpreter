copy c:\tasm\tdc2.td tdconfig.conf
tasm /zi test.asm
tlink /v/3 test.obj
td -ctdconfig.conf d:\test.exe hello.b