extends Node

var dialogResult : String;
var nameToDrop : String;

func resetForNewDialog() -> void:
	dialogResult = "";
	
func getResultFromLastDialog() -> String:
	return dialogResult;

func checkNameDrop() -> bool:
	nameToDrop = "Jacko McBean"
	return true;
