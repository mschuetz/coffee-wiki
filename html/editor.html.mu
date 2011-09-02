<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8" />
		<title>Editing: {{title}}</title>
		<link href="/__css__" rel="stylesheet"/>
	</head>
	<body>
		Editing {{title}}
		<div> 
		<form method="POST" action="/{{title}}" >
			<p><textarea name="content" cols="80" rows="30">{{content}}</textarea></p>
			<button>Save</button>
		</form>
		</div>
	</body>
</html>