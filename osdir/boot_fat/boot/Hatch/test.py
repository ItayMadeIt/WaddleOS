with open("kernel.elf", "wb") as file:
	for i in range(46):
		file.write(("Awesome message made by me, to you Steve!".encode()) + (f"{i:02x}").encode() + "\x0A\x0D".encode())
