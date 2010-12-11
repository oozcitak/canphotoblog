dev: libs
	@echo 'Building...'
	@test `which coffee` || echo 'You need to have CoffeeScript installed.'
	@coffee -c -o lib/libs/ src/libs/*.coffee
	@coffee -c -o lib/models/ src/models/*.coffee
	@coffee -c -o lib/controllers/ src/controllers/*.coffee
	@coffee -c -o lib/ src/*.coffee

libs: clean
	@echo 'Copying libraries'
	@mkdir lib/
	@mkdir lib/libs
	@cp src/libs/*.js lib/libs/

clean:
	@echo 'Cleaning build'
	@rm -fr lib/
