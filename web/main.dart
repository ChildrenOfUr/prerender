import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'package:prerender/prerender.dart';
import 'package:stagexl/stagexl.dart';

List<String> streetsToParse = ['GA58KK7B9O522PC'];
List<String> streetsParsed = [];

main() async {
	StageXL.stageOptions
		..transparent = true
		..backgroundColor = 0x00000000;
	new RenderLoop()
		..addStage(STAGE);

	await parseStreets();

	print('done!');
}

Future parseStreets() async {
	while (streetsToParse.isNotEmpty) {
		String currentTsid = streetsToParse.removeLast();
		streetsParsed.add(currentTsid);
		Map street = await getStreet(currentTsid);
		String currentLabel = street['label'];
		print('parsing $currentLabel');

		Map response = await prerender(street);

		print(response.toString());
		//now upload renderedStreet
		await HttpRequest.request('http://localhost:8181/uploadStreetRender', method: "POST",
		                          requestHeaders: {"content-type": "application/json"},
		                          sendData: JSON.encode(response));

		List<Map> signposts = street['dynamic']['layers']['middleground']['signposts'];
		signposts.forEach((Map signpost) {
			List<Map> connects = signpost['connects'];
			connects.forEach((Map connection) {
				String tsid = connection['tsid'];
				String label = connection['label'];
				if (!streetsParsed.contains(tsid)) {
					streetsToParse.add(tsid);
					print('queuing up $label');
				}
			});
		});
	}
}

Future<Map> getStreet(String tsid) async {
	if (tsid.startsWith('L')) {
		tsid = tsid.replaceFirst('L', 'G');
	}
	String url = "http://RobertMcDermot.github.io/CAT422-glitch-location-viewer/locations/$tsid.json";
	String response = await HttpRequest.getString(url);

	Map street = JSON.decode(response);
	return street;
}