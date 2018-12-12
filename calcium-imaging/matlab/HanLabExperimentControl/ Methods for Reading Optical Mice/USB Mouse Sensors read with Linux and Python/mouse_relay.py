#!/usr/bin/python

from serial import Serial
from threading import Thread Lock

try:
	# Open serial port and mouse interfaces -> store mouse-data in dicts
	sr = Serial(0)
	# Dictionaries/structures containing data for each 'SENSOR'
	mouse1 = {
		'Name': '1',
		'File': file('/dev/input/mouse1'),
		'dx': 0,
		'dy': 0};
	mouse2 = {
		'Name': '2',
		'File': file('/dev/input/mouse2'),
		'dx': 0,
		'dy': 0};
	mouse_input = [mouse1, mouse2]
	# Declare variables
	transmit_timer = None
	data_lock = Lock
	serial_lock = Lock
	transmit_delay = .1
	read_delay = .01
	print('mouse_relay.py: \n\tMain thread initialized\n\tDefining I/O threads\n')


	# SENDOUTPUTTHREAD - class for sending data over serial port, subclass of Thread class
	class SendOutputThread(Thread)
		# Call parent (Thread) constructor with additional argument: SENSOR
		def __init__(self, sensor):
		        Thread.__init__(self)	        
		        self.sensor = sensor
		# Running code goes in 'run' method, called by obj.start() method
		def run(self):
			while true:
				# Convert and Reset dx/dy data
				data_lock.acquire()
				s = sensor['Name']
				dx = str(sensor['dx'])
				sensor['dx'] = 0
				dy = str(sensor['dy'])
				sensor['dy'] = 0
				data_lock.release()
				# Format and Transmit data as string, e.g. (12,-39) = '1x12y-39' 
				datastring = s + 'x'+dx + 'y'+dy
				serial_lock.acquire()
				sr.write(datastring,'\n')
				serial_lock.release()
				print datastring 
				# Delay for transmission period (100 msec)
				time.sleep(transmit_delay)		

	# READINPUTTHREAD - class to read raw input from linux /dev/mouseX files
	class ReadInputThread(Thread)
		# Call parent (Thread) constructor with additional argument: SENSOR
		def __init__(self, sensor):
		        Thread.__init__(self)	        
		        self.sensor = sensor
		# Running code goes in 'run' method, called by obj.start() method
		def run(self):
			while True:
				newdx = newdy = 0
				# Read raw values from mouse device file in linux filesystem
				dev_file = sensor['File']
				status, newdx, newdy = tuple(ord(c) for c in dev_file.read(3))
				# Define conversion to signed integer
				def to_signed(n):
					return n - ((0x80 & n) << 1)
				# Add accumulated readings
				if status:
					data_lock.acquire()
					sensor['dx'] += to_signed(newdx)
					sensor['dy'] += to_signed(newdy)
					data_lock.release()
				time.sleep(read_delay)
	print('\tI/O threads defined\n\t...initializing now\n')
			
	# Begin a transmitting thread for each mouse: SEND_OUTPUT
	serial_out_thread1 = SendOutputThread(mouse1)
	serial_out_thread2 = SendOutputThread(mouse2)
	serial_out_thread1.setName('thread_out_mouse1')
	serial_out_thread2.setName('thread_out_mouse2')
			
	# Begin the sensing thread for each mouse: READ_INPUT
	devread_in_thread1 = ReadInputThread(mouse1)
	devread_in_thread2 = ReadInputThread(mouse2)
	devread_in_thread1.setName('thread_in_mouse1')
	devread_in_thread2.setName('thread_in_mouse2')
	print('\tThreads initialized... starting all threads now\n')

	# Start all threads
	serial_out_thread1.start()
	serial_out_thread2.start()
	devread_in_thread1.start()
	devread_in_thread2.start()
			
	# Join all threads to prevent program exit
	serial_out_thread1.join()
	serial_out_thread2.join()
	devread_in_thread1.join()
	devread_in_thread2.join()
except Exception as dang:
	sr.close()
	print('\n\nError occurred... closing Serial Port...\n\n\tError:\n\t\t')
	print(str(dang))
else:
	sr.close()
	print('\n\nShutting down safely...')
	
		
		
		
		
		
		
		
		
