import 'uplink_decoder.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_profile.dart' show shortUuid;
import 'disconnect_guard.dart';
import 'livestock_protocol.dart';
import 'livestock_exchange.dart';

class LivestockSetupPage extends StatefulWidget {
  final BluetoothDevice? device;
  final List<BluetoothService> services;
  const LivestockSetupPage({super.key,this.device,this.services=const []});
  @override State<LivestockSetupPage> createState()=>_LivestockSetupPageState();
}
class _LivestockSetupPageState extends State<LivestockSetupPage> {
  final values=<int,String>{};
  final history=<String>[];
  final info=<String,String>{};
  BluetoothCharacteristic? field(String id){final found=widget.services.expand((s)=>s.characteristics).where((c)=>shortUuid(c.uuid.str)==id).toList();return found.length==1?found.first:null;}
  static const infoLabels={'ff81':'LoRaWAN region','ff82':'LoRaWAN sub-band','ff87':'Network status','2a19':'Battery','2a26':'Firmware version'};
  bool busy=false;
  String status='',geofence='',assetRule='';
  int generation=0;
  StreamSubscription<BluetoothConnectionState>? link;
  bool get connected=>widget.device?.isConnected??false;
  BluetoothCharacteristic? get command {
    final found=widget.services.expand((s)=>s.characteristics).where((c)=>shortUuid(c.uuid.str)=='ff84').toList();
    return found.length==1?found.first:null;
  }
  @override void initState(){
    super.initState();
    link=widget.device?.connectionState.listen((s){if(!mounted)return;if(s==BluetoothConnectionState.disconnected){generation++;setState((){values.clear();info.clear();geofence='';assetRule='';status='Disconnected';});}});
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted && connected)readAll();});
  }
  @override void dispose(){generation++;link?.cancel();super.dispose();}
  Future<List<int>> exchange(List<int> request,int response,int id,{int? width}) async {
    final c=command;
    if(c==null || !connected)throw StateError('Connect to the tracker first.');
    final epoch=generation;
    history.add('TX ${lsHex(request)}');
    final reply=await livestockExchange(c,request,accepts:(b)=>b.length>=2 && b[0]==response && b[1]==id && (width==null || b.length==2+width));
    if(!mounted || epoch!=generation || !connected)throw StateError('Connection closed');
    history.add('RX ${lsHex(reply)}');
    if(history.length>100)history.removeRange(0,history.length-100);
    return reply.sublist(2);
  }
  Future<void> readAll() async {
    if(busy || !connected || command==null)return;
    setState((){busy=true;values.clear();status='Reading tracker…';});
    final epoch=generation;
    for(final id in infoLabels.keys){
      final c=field(id);
      if(c==null || !c.properties.read)continue;
      try{final b=await c.read(timeout:3);if(!mounted || epoch!=generation)break;final text=id=='2a19' && b.length==1?'${b.first}%':utf8.decode(b).replaceAll(RegExp(r'\x00+$'),'').trim();setState(()=>info[id]=text);}catch(_){info.remove(id);}
    }
    var failures=0,count=0;
    for(final p in livestockParameters){
      if(!mounted || !connected)break;
      try{
        final b=await exchange([0xb0,p.id],0x6b,p.id,width:p.width);
        final v=p.decode(b);
        if(mounted)setState((){values[p.id]=v;status='Reading ${p.name}…';});
        failures=0;count++;
      }catch(e){history.add('${p.name}: $e');failures++;if(failures>=3)break;}
    }
    if(mounted && connected && failures<3){
      try{assetRule=lsHex(await exchange([0xb0,12],0x6b,12));validateAssetRule(lsBytes(assetRule));}catch(_){assetRule='';}
      try{geofence=polygonText(await exchange([0xb0,48],0x6b,48));}catch(_){geofence='';}
    }
    if(mounted)setState((){busy=false;status=connected?'Read $count settings':'Disconnected';});
  }
  Future<bool> approve(String title,String body) async => await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:Text(title),content:SingleChildScrollView(child:Text(body)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Confirm'))]))??false;
  Future<void> perform(Future<void> Function() action) async {
    if(busy)return;
    setState(()=>busy=true);
    try{await action();}catch(e){if(mounted)setState(()=>status=e is TimeoutException?'No response. Refresh to check the current value.':'$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> edit(LivestockParameter p) async {
    final controller=TextEditingController(text:values[p.id]??'');
    String? selected=values[p.id];
    final entered=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:Text(p.name),content:
      p.choices==null?TextField(controller:controller,autofocus:true,keyboardType:p.width==16?TextInputType.text:TextInputType.number,decoration:InputDecoration(helperText:p.width==16?'Beacon UUID':'${p.min*p.step}–${p.max*p.step} ${p.unit}; step ${p.step}')):
      DropdownButtonFormField<String>(value:selected,items:[for(var i=0;i<p.choices!.length;i++)DropdownMenuItem(value:'$i',child:Text(p.choices![i]))],onChanged:(v)=>selected=v),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,p.choices==null?controller.text:selected),child:Text(widget.device==null?'Create command':'Apply'))]));
    // Dialog text controller is released after the closing animation.
    Future<void>.delayed(const Duration(milliseconds:400),controller.dispose);
    if(entered==null || !mounted)return;
    await perform(() async {
      final encoded=p.encode(entered);
      if(widget.device==null){await copy([0xa0,p.id,...encoded]);return;}
      validateLivestockRelations(p.id,entered,values,polygon:geofence.isNotEmpty);
      await exchange([0xa0,p.id,...encoded],0x6a,p.id,width:0);
      values.remove(p.id);
      final back=await exchange([0xb0,p.id],0x6b,p.id,width:p.width);
      final actual=p.decode(back);
      if(mounted)setState((){values[p.id]=actual;status=lsHex(back)==lsHex(encoded)?'Saved and verified':'Device returned a different value';});
    });
  }
  Future<void> copy(List<int> command) async {
    await Clipboard.setData(ClipboardData(text:lsHex(command)));
    if(mounted)setState(()=>status='Command copied: ${lsHex(command)}');
  }
  Future<void> editSpecial(bool polygon) async {
    final controller=TextEditingController(text:polygon?geofence:assetRule);
    final entered=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(polygon?'Geofence':'Asset filter'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(!polygon)Wrap(spacing:8,children:[TextButton(onPressed:()=>controller.text='1203000502001E',child:const Text('MAC + advertising')),TextButton(onPressed:()=>controller.text='12010918F2A52D43E0AB489CB64C4A830014672002191C',child:const Text('iBeacon Major / Minor'))]),
        TextField(controller:controller,minLines:polygon?4:2,maxLines:8,decoration:InputDecoration(hintText:polygon?'120.0000000, 30.0000000\n120.0100000, 30.0000000\n120.0000000, 30.0100000':'Asset rule (hex)',helperText:polygon?'3–8 points, longitude then latitude, counter-clockwise':null)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('Review'))]));
    Future<void>.delayed(const Duration(milliseconds:400),controller.dispose);
    if(!mounted || entered==null)return;
    await perform(() async {
      final bytes=polygon?livestockPolygon(entered):lsBytes(entered);
      if(!polygon)validateAssetRule(bytes);
      final request=polygon?bytes:[0xa0,12,...bytes];
      if(widget.device==null){await copy(request);return;}
      if(!await approve('Save ${polygon?'geofence':'asset filter'}?',entered) || !mounted)return;
      await exchange(request,polygon?0x6d:0x6a,polygon?bytes[1]:12,width:0);
      if(polygon){geofence='';final back=await exchange([0xb0,48],0x6b,48);geofence=polygonText(back);if(lsHex(back)!=lsHex(bytes.sublist(1)))throw StateError('Device returned a different geofence');}
      else{assetRule='';final back=await exchange([0xb0,12],0x6b,12);validateAssetRule(back);assetRule=lsHex(back);if(assetRule!=lsHex(bytes))throw StateError('Device returned a different filter');}
      if(mounted)setState(()=>status='Saved and verified');
    });
  }
  Future<void> action(int id,String title) async {
    if(!await approve('$title?',id==4?'All tracker settings will be restored to factory defaults.':'Livestock Tracker') || !mounted)return;
    await perform(() async {if(widget.device==null){await copy([0xc0,id]);return;}await exchange([0xc0,id],0x6c,id,width:0);if(mounted)setState(()=>status='$title: confirmed');});
  }
  int get bandMaximum {
    final region=(info['ff81']??'').toUpperCase();
    if(region.contains('CN470'))return 12;
    if(['US915','AU915','LA915'].any(region.contains))return 8;
    return 0;
  }
  Future<void> editBand() async {
    final controller=TextEditingController(text:info['ff82']??'AUTO');
    final value=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('LoRaWAN sub-band'),content:TextField(controller:controller,decoration:InputDecoration(helperText:'AUTO or 1–$bandMaximum')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('Apply'))]));
    Future<void>.delayed(const Duration(milliseconds:400),controller.dispose);
    if(value==null || !mounted)return;
    await perform(()async{
      final v=value.trim().toUpperCase(),n=int.tryParse(value.trim());
      if(v!='AUTO' && (n==null || n<0 || n>bandMaximum))throw FormatException('Enter AUTO or 1–$bandMaximum');
      final c=field('ff82');if(c==null || !connected)throw StateError('Connect to the tracker first.');
      final epoch=generation;
      await c.write(utf8.encode(v),withoutResponse:!c.properties.write,timeout:5);
      info.remove('ff82');
      final read=utf8.decode(await c.read(timeout:3)).replaceAll(RegExp(r'\x00+$'),'').trim().toUpperCase();
      if(!mounted || epoch!=generation)return;
      final same=read==v || (['AUTO','0'].contains(read) && ['AUTO','0'].contains(v));
      setState((){info['ff82']=read;status=same?'Sub-band saved. Restart the tracker to apply.':'Device returned a different sub-band';});
    });
  }
  Future<void> decode() async {
    final controller=TextEditingController();
    final raw=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Decode Livestock report'),content:TextField(controller:controller,maxLines:5,decoration:const InputDecoration(labelText:'LoRaWAN payload (hex), FPort 8')),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text),child:const Text('Decode'))]));
    Future<void>.delayed(const Duration(milliseconds:400),controller.dispose);
    if(raw==null || !mounted)return;
    try{final payload=lsHex(lsBytes(raw));final decoded=await decodeUplink('livestock',payload);if(!mounted)return;await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Livestock report'),content:SingleChildScrollView(child:SelectableText(const JsonEncoder.withIndent('  ').convert(jsonDecode(decoded)))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));}catch(e){if(mounted)setState(()=>status='Could not decode report: $e');}
  }
  @override Widget build(BuildContext context)=>DisconnectGuard(connected:connected,busy:busy,child:Scaffold(
    appBar:AppBar(title:const Text('Livestock Tracker'),actions:[IconButton(tooltip:'Refresh',onPressed:busy||!connected?null:readAll,icon:const Icon(Icons.refresh)),IconButton(tooltip:'Copy diagnostics',onPressed:()async{await Clipboard.setData(ClipboardData(text:['Ls BLE Guided 1.5.4',status,...history].join('\n')));},icon:const Icon(Icons.copy))]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      if(busy)const LinearProgressIndicator(),
      if(status.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:SelectableText(status)),
      for(final entry in info.entries)ListTile(title:Text(infoLabels[entry.key]!),subtitle:Text(entry.value),trailing:entry.key=='ff82' && bandMaximum>0?const Icon(Icons.edit):null,onTap:entry.key=='ff82' && bandMaximum>0 && !busy?editBand:null),
      for(final group in livestockParameters.map((p)=>p.group).toSet())...[
        Padding(padding:const EdgeInsets.only(top:20,bottom:8),child:Text(group,style:Theme.of(context).textTheme.titleLarge)),
        for(final p in livestockParameters.where((p)=>p.group==group))Card(child:ListTile(title:Text(p.name),subtitle:Text(values.containsKey(p.id)?p.display(values[p.id]!):'—'),trailing:const Icon(Icons.chevron_right),onTap:busy || (widget.device!=null && !connected)?null:()=>edit(p))),
      ],
      ListTile(title:const Text('Asset filter'),subtitle:Text(assetRule.isEmpty?'—':'Loaded'),trailing:const Icon(Icons.chevron_right),onTap:busy?null:()=>editSpecial(false)),
      ListTile(title:const Text('Geofence boundary'),subtitle:Text(geofence.isEmpty?'—':'${geofence.split('\n').length} points'),trailing:const Icon(Icons.chevron_right),onTap:busy?null:()=>editSpecial(true)),
      for(final a in {1:'Request position',2:'Send registration',3:'Restart device',4:'Restore factory defaults'}.entries)OutlinedButton(onPressed:busy?null:()=>action(a.key,a.value),child:Text(a.value)),
      OutlinedButton(onPressed:decode,child:const Text('Decode LoRaWAN report')),
    ])));
}
