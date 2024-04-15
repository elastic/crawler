# Load our common shell functions library
source "$(dirname $0)/functions.sh"

# Fail the script in case of any errors
set -e

# Tune for faster startup
export JRUBY_OPTS="${JRUBY_OPTS:-} --dev --debug"
export JAVA_OPTS="-Xmx2g ${JAVA_OPTS:-} -Djava.awt.headless=true -Dsun.jnu.encoding=UTF-8 -Dfile.encoding=UTF-8 -XX:+HeapDumpOnOutOfMemoryError"

# Load version files for ruby and java
load_version_constraints

echo "----------------------------------------"
echo "JRuby version required: ${JRUBY_VERSION}"
echo "Java version required: ${JAVA_VERSION}"
echo "----------------------------------------"

# Enable the right java version
jenv_init
jenv shell "$JAVA_VERSION"

# Switch to jruby
rbenv_init
rbenv shell "$JRUBY_VERSION"

# Check dependencies and install if needed
check_bundle
check_yarn
