library main;

import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'package:prerender/prerender.dart';
import 'package:prerender/API_KEYS.dart';
import 'package:stagexl/stagexl.dart';

List<String> streetsParsed = [];

main() async {
	StageXL.stageOptions
		..transparent = true
		..backgroundColor = 0x00000000;
	new RenderLoop()
		..addStage(STAGE);

	ButtonElement doIt = querySelector("#DoIt");
	doIt.onClick.listen((_) async {
		TextAreaElement streetList = querySelector("#StreetList");
		List<String> streets = streetList.value.split('\n');
		streets.removeWhere((String street) => street.isEmpty);
		print('$streets : ${streets.length}');
		querySelector("#LoadingDialog").hidden = false;
		parseStreets(streets);
	});

	resize();
	window.onResize.listen((_) => resize());
}

resize() {
	int topHeight = querySelector('#TopBit').clientHeight;
	int remaining = document.body.clientHeight - topHeight - 50;
	querySelector('#LayerWindow').style.height = '${remaining}px';
}

Future parseStreets(List<String> streetsToParse) async {
//	List<String> streetsToParse = ['GM11E7ODKHO1QJE'];

	while (streetsToParse.isNotEmpty) {
		String currentTsid = streetsToParse.removeLast();
		Map street = await getStreet(currentTsid);
		String currentLabel = street['label'];
		querySelector("#CurrentRender").text = 'Rendering: $currentLabel';

		Map response = await prerender(street);
		response['redstoneToken'] = redstoneToken;

		//now upload renderedStreet
		HttpRequest request = await HttpRequest.request('http://robertmcdermot.com:8181/uploadStreetRender', method: "POST",
			requestHeaders: {"content-type": "application/json"},
			sendData: JSON.encode(response));

		print('got ${request.response.toString()}');

//		streetsParsed.add(currentTsid);
//		window.localStorage['parsed'] = JSON.encode(streetsParsed);
//		window.localStorage['toParse'] = JSON.encode(streetsToParse);

//		List<Map> signposts = street['dynamic']['layers']['middleground']['signposts'];
//		signposts.forEach((Map signpost) {
//			List<Map> connects = signpost['connects'];
//			connects.forEach((Map connection) {
//				String tsid = connection['tsid'];
//				String label = connection['label'];
//				if (!streetsParsed.contains(tsid)) {
//					streetsToParse.add(tsid);
//					print('queuing up $label');
//				}
//			});
//		});
	}

	querySelector("#LoadingDialog").hidden = true;
	(querySelector("#StreetList") as TextAreaElement).value = '';
	window.alert('DONE!');
}

Future<Map> getStreet(String tsid) async {
	if (tsid.startsWith('L')) {
		tsid = tsid.replaceFirst('L', 'G');
	}
	String url = 
"https://rawgit.com/ChildrenOfUr/CAT422-glitch-location-viewer/master/locations/$tsid.json";
	String response = await HttpRequest.getString(url);

	Map street = JSON.decode(response);
	return street;
}
