dev: clean
	@echo 'Copying libraries...'
	@mkdir lib/
	@mkdir lib/libs
	@cp src/libs/*.js lib/libs/
	@echo 'Building...'
	@test `which coffee` || echo 'You need to have CoffeeScript installed.'
	@coffee -c -o lib/libs/ src/libs/*.coffee
	@coffee -c -o lib/models/ src/models/*.coffee
	@coffee -c -o lib/controllers/ src/controllers/*.coffee
	@coffee -c -o lib/ src/*.coffee

clean:
	@echo 'Cleaning build...'
	@rm -fr lib/

test: dev
	@echo 'Running application...'
	@test `which node` || echo 'You need to have node.js installed.'
	@node run.js

