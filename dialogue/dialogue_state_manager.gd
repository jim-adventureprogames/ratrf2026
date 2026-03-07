extends Node

var dialogResult : String;
var nameToDrop : String;
var activeSignInformation: String;

func resetForNewDialog() -> void:
	dialogResult = "";
	
func getResultFromLastDialog() -> String:
	return dialogResult;

func checkNameDrop() -> bool:
	nameToDrop = "Jacko McBean"
	return true;

func setActiveSignInformation(msg: String) -> void:
	activeSignInformation = msg;

func checkTutorial(tutorialName : String) -> bool:
	return TutorialManager.summon().getTutorialSteps(tutorialName) > 0
	

func advanceTutorial(tutorialName : String) -> void:
	TutorialManager.summon().advanceTutorial(tutorialName);
	
	
