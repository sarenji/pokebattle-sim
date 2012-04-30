HTMLDOCS = $(DOCS:.md=.html)
REPORTER = dot

test:
	NODE_ENV=test ./node_modules/.bin/mocha \
		--reporter $(REPORTER) --require should --compilers coffee:coffee-script


test-cov: lib-cov
	NUGGETBRIDGE_COV=1 $(MAKE) test REPORTER=html-cov > coverage.html

lib-cov:
	rm -rf server-cov
	coffee -c server
	jscoverage server server-cov
	rm server/*.js

.PHONY: test
