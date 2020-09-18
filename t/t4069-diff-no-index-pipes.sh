#!/bin/sh

test_description='diff --no-index requiring bash (process expansion)'

. ./lib-bash.sh

test_expect_success 'setup' '
	mkdir a &&
	mkdir b &&
	echo 1 >a/1 &&
	echo 2 >a/2 &&
	git init repo &&
	echo 1 >repo/a &&
	mkdir -p non/git &&
	echo 1 >non/git/a &&
	echo 1 >non/git/b &&
	echo in-repo >repo/a &&
	echo non-repo >non/git/a &&
	mkdir non/git/sub &&
	echo sub-repo >non/git/sub/a &&
	mkdir non/git/d non/git/e non/git/e/sub &&
	echo 1 >non/git/d/sub &&
	echo 2 >non/git/e/sub/file
'

test_expect_success 'diff --no-index can diff piped subshells' '
	echo 1 >non/git/c &&
	test_expect_code 0 git diff --no-index non/git/b <(cat non/git/c) &&
	test_expect_code 0 git diff --no-index <(cat non/git/b) non/git/c &&
	test_expect_code 0 git diff --no-index <(cat non/git/b) <(cat non/git/c) &&
	test_expect_code 0 cat non/git/b | git diff --no-index - non/git/c &&
	test_expect_code 0 cat non/git/c | git diff --no-index non/git/b - &&
	test_expect_code 0 cat non/git/b | git diff --no-index - <(cat non/git/c) &&
	test_expect_code 0 cat non/git/c | git diff --no-index <(cat non/git/b) -
'

test_expect_success 'diff --no-index finds diff in piped subshells' '
	(
		set -- <(cat /dev/null) <(cat /dev/null)
		cat <<-EOF >expect
			diff --git a$1 b$2
			--- a$1
			+++ b$2
			@@ -1 +1 @@
			-1
			+2
		EOF
	) &&
	test_expect_code 1 \
		git diff --no-index <(cat non/git/b) <(sed s/1/2/ non/git/c) >actual &&
	test_cmp expect actual
'

test_expect_success 'diff --no-index with stat and numstat' '
	(
		set -- <(cat /dev/null) <(cat /dev/null)
		min=$((${#1} < ${#2} ? ${#1} : ${#2}))
		for ((i=0; i<min; i++)); do [ "${1:i:1}" = "${2:i:1}" ] || break; done
		base=${1:0:i-1}
		cat <<-EOF >expect1
			 $base{${1#$base} => ${2#$base}} | 2 +-
			 1 file changed, 1 insertion(+), 1 deletion(-)
		EOF
		cat <<-EOF >expect2
			1	1	$base{${1#$base} => ${2#$base}}
		EOF
	) &&
	test_expect_code 1 \
		git diff --no-index --stat <(cat non/git/a) <(sed s/1/2/ non/git/b) >actual &&
	test_cmp expect1 actual &&
	test_expect_code 1 \
		git diff --no-index --numstat <(cat non/git/a) <(sed s/1/2/ non/git/b) >actual &&
	test_cmp expect2 actual
'

test_expect_success PIPE 'diff --no-index on filesystem pipes' '
	(
		cd non/git &&
		mkdir f g &&
		mkfifo f/1 g/1 &&
		test_expect_code 128 git diff --no-index f g &&
		test_expect_code 128 git diff --no-index ../../a f &&
		test_expect_code 128 git diff --no-index g ../../a &&
		test_expect_code 128 git diff --no-index f/1 g/1 &&
		test_expect_code 128 git diff --no-index f/1 ../../a/1 &&
		test_expect_code 128 git diff --no-index ../../a/1 g/1
	)
'

test_expect_success PIPE 'diff --no-index reads symlinks to named pipes as symlinks' '
	(
		cd non/git &&
		mkdir h i &&
		ln -s ../f/1 h/1 &&
		ln -s ../g/1 i/1 &&
		test_expect_code 1 git diff --no-index h i >actual &&
		cat <<-EOF >expect &&
			diff --git a/h/1 b/i/1
			index d0b5850..d8b9c34 120000
			--- a/h/1
			+++ b/i/1
			@@ -1 +1 @@
			-../f/1
			\ No newline at end of file
			+../g/1
			\ No newline at end of file
		EOF
		test_cmp expect actual &&
		test_expect_code 1 git diff --no-index ../../a h >actual &&
		cat <<-EOF >expect &&
			diff --git a/../../a/1 b/../../a/1
			deleted file mode 100644
			index d00491f..0000000
			--- a/../../a/1
			+++ /dev/null
			@@ -1 +0,0 @@
			-1
			diff --git a/h/1 b/h/1
			new file mode 120000
			index 0000000..d0b5850
			--- /dev/null
			+++ b/h/1
			@@ -0,0 +1 @@
			+../f/1
			\ No newline at end of file
			diff --git a/../../a/2 b/../../a/2
			deleted file mode 100644
			index 0cfbf08..0000000
			--- a/../../a/2
			+++ /dev/null
			@@ -1 +0,0 @@
			-2
		EOF
		test_cmp expect actual &&
		test_expect_code 1 git diff --no-index i ../../a >actual &&
		cat <<-EOF >expect &&
			diff --git a/i/1 b/i/1
			deleted file mode 120000
			index d8b9c34..0000000
			--- a/i/1
			+++ /dev/null
			@@ -1 +0,0 @@
			-../g/1
			\ No newline at end of file
			diff --git a/../../a/1 b/../../a/1
			new file mode 100644
			index 0000000..d00491f
			--- /dev/null
			+++ b/../../a/1
			@@ -0,0 +1 @@
			+1
			diff --git a/../../a/2 b/../../a/2
			new file mode 100644
			index 0000000..0cfbf08
			--- /dev/null
			+++ b/../../a/2
			@@ -0,0 +1 @@
			+2
		EOF
		test_cmp expect actual &&
		test_expect_code 1 git diff --no-index h/1 i/1 >actual &&
		cat <<-EOF >expect &&
			diff --git a/h/1 b/i/1
			index d0b5850..d8b9c34 120000
			--- a/h/1
			+++ b/i/1
			@@ -1 +1 @@
			-../f/1
			\ No newline at end of file
			+../g/1
			\ No newline at end of file
		EOF
		test_cmp expect actual &&
		test_expect_code 1 git diff --no-index h/1 ../../a/1 >actual &&
		cat <<-EOF >expect &&
			diff --git a/h/1 b/h/1
			deleted file mode 120000
			index d0b5850..0000000
			--- a/h/1
			+++ /dev/null
			@@ -1 +0,0 @@
			-../f/1
			\ No newline at end of file
			diff --git a/../../a/1 b/../../a/1
			new file mode 100644
			index 0000000..d00491f
			--- /dev/null
			+++ b/../../a/1
			@@ -0,0 +1 @@
			+1
		EOF
		test_cmp expect actual &&
		test_expect_code 1 git diff --no-index ../../a/1 i/1 >actual &&
		cat <<-EOF >expect &&
			diff --git a/../../a/1 b/../../a/1
			deleted file mode 100644
			index d00491f..0000000
			--- a/../../a/1
			+++ /dev/null
			@@ -1 +0,0 @@
			-1
			diff --git a/i/1 b/i/1
			new file mode 120000
			index 0000000..d8b9c34
			--- /dev/null
			+++ b/i/1
			@@ -0,0 +1 @@
			+../g/1
			\ No newline at end of file
		EOF
		test_cmp expect actual
	)
'

test_done
