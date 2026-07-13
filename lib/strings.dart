import 'dart:ui' show PlatformDispatcher;

import 'prefs.dart';

/// UI 문자열 (ko/en). Prefs.lang이 'system'이면 기기 언어를 따른다.
class S {
  static bool get ko {
    final lang = Prefs.lang;
    if (lang == 'ko') return true;
    if (lang == 'en') return false;
    return PlatformDispatcher.instance.locale.languageCode == 'ko';
  }

  static String get appName => ko ? '그냥 리더' : 'gnyang Reader';

  // 홈
  static String get download => ko ? '다운로드' : 'Downloads';
  static String get documents => ko ? '문서' : 'Documents';
  static String get allStorage => ko ? '전체' : 'All files';
  static String get recentFiles => ko ? '최근 연 파일' : 'Recently opened';
  static String get shortcuts => ko ? '바로가기' : 'Shortcuts';
  static String get sdcard => ko ? 'SD 카드' : 'SD card';
  static String get pinned => ko ? '고정' : 'Pinned';
  static String get pinAdded => ko ? '고정했어요' : 'Pinned';
  static String get pinRemoved => ko ? '고정을 해제했어요' : 'Unpinned';
  static String get recentDownloads => ko ? '최근 받은 파일' : 'Recently added';
  static String get all => ko ? '전체' : 'All';
  static String get searchingFiles => ko ? '모으는 중…' : 'Collecting…';
  static String get noRecent => ko
      ? '아직 연 파일이 없어요.\n위에서 폴더를 열거나, 파일 앱에서 문서를 탭해 보세요.'
      : 'Nothing opened yet.\nBrowse a folder above, or tap a document in your Files app.';
  static String get fileGone =>
      ko ? '파일이 삭제되었거나 이동했어요' : 'This file was deleted or moved';
  static String get needStorageTitle =>
      ko ? '저장소 접근 권한이 필요해요' : 'Storage access needed';
  static String get needStorageBody => ko
      ? '기기의 문서 파일을 읽기 위한 권한이에요. 한 번만 허용하면 돼요.'
      : 'This lets the app read documents on your device. One-time setup.';
  static String get grantPermission => ko ? '권한 허용하기' : 'Grant access';

  // 탐색기
  static String get internalStorage => ko ? '내장 저장소' : 'Internal storage';
  static String get sortName => ko ? '이름순' : 'Name';
  static String get sortDate => ko ? '최신순' : 'Date';
  static String get sortSize => ko ? '크기순' : 'Size';
  static String get searchInFolder => ko ? '파일명 검색' : 'Search files';
  static String get cantAccess =>
      ko ? '이 폴더에 접근할 수 없어요' : 'Can\'t access this folder';
  static String get emptyFolder =>
      ko ? '표시할 문서가 없어요' : 'No documents here';

  // 설정
  static String get settings => ko ? '설정' : 'Settings';
  static String get general => ko ? '일반' : 'General';
  static String get language => ko ? '언어' : 'Language';
  static String get systemDefault => ko ? '시스템' : 'System';
  static String get theme => ko ? '테마' : 'Theme';
  static String get light => ko ? '라이트' : 'Light';
  static String get dark => ko ? '다크' : 'Dark';
  static String get sepia => ko ? '세피아' : 'Sepia';
  static String get brightness => ko ? '밝기' : 'Brightness';
  static String get reading => ko ? '읽기' : 'Reading';
  static String get readingHint => ko
      ? 'md · txt 문서에 적용돼요 (epub은 글자 크기만)'
      : 'Applies to md · txt (epub: font size only)';
  static String get fontSize => ko ? '글자 크기' : 'Font size';
  static String get lineHeight => ko ? '줄 간격' : 'Line spacing';
  static String get pageMode => ko ? '페이지 모드' : 'Page mode';
  static String get pageModeHint => ko
      ? 'pdf · epub · md · txt에 적용돼요'
      : 'Applies to pdf · epub · md · txt';
  static String get scrollMode => ko ? '스크롤' : 'Scroll';
  static String get swipeMode => ko ? '스와이프' : 'Swipe';
  static String get keepScreenOn => ko ? '화면 꺼짐 방지' : 'Keep screen on';
  static String get keepScreenOnHint =>
      ko ? '문서를 보는 동안 화면이 꺼지지 않아요' : 'Screen stays on while reading';
  static String get about => ko ? '정보' : 'About';
  static String get checkUpdate => ko ? '업데이트 확인' : 'Check for updates';
  static String get version => ko ? '버전' : 'Version';
  static String get sourceCode => ko ? '소스 코드' : 'Source code';
  static String get buyMilkTea => ko ? '개발자에게 밀크티 한 잔 🧋' : 'Buy the dev a milk tea 🧋';
  static String get buyMilkTeaHint =>
      ko ? '광고 없이 만드는 데 힘이 돼요' : 'Helps keep this ad-free';
  static String get aboutBody => ko
      ? '광고 없는 문서 뷰어.\npdf · docx · hwp · hwpx · html · md · txt · xlsx · epub'
      : 'An ad-free document viewer.\npdf · docx · hwp · hwpx · html · md · txt · xlsx · epub';

  // 뷰어
  static String get search => ko ? '문서에서 찾기' : 'Find in document';
  static String get share => ko ? '공유' : 'Share';
  static String get cantOpenFile =>
      ko ? '파일을 열지 못했어요' : "Couldn't open this file";
  static String get cantOpenBody => ko
      ? '지원하지 않는 형식이거나 파일이 손상됐을 수 있어요.'
      : 'The format may be unsupported or the file may be damaged.';
  static String get openWith => ko ? '다른 앱으로 열기' : 'Open with another app';
  static String get delete => ko ? '삭제' : 'Delete';
  static String get cancel => ko ? '취소' : 'Cancel';
  static String get deleteConfirm => ko
      ? '이 파일을 기기에서 삭제할까요? 되돌릴 수 없어요.'
      : 'Delete this file from your device? This cannot be undone.';
  static String get deleted => ko ? '삭제했어요' : 'Deleted';
  static String get deleteFailed => ko ? '삭제하지 못했어요' : "Couldn't delete";

  // 업데이트
  static String get updateNotConfigured =>
      ko ? '업데이트 저장소가 아직 설정되지 않았어요.' : 'Update source is not configured yet.';
  static String upToDate(String v) =>
      ko ? '최신 버전이에요 (v$v)' : 'You\'re up to date (v$v)';
  static String newVersion(String v) => ko ? '새 버전 v$v' : 'New version v$v';
  static String updateBody(String cur, String latest) => ko
      ? '현재 v$cur → v$latest 업데이트가 있어요.'
      : 'Update available: v$cur → v$latest.';
  static String get later => ko ? '나중에' : 'Later';
  static String get update => ko ? '업데이트' : 'Update';
  static String get downloading => ko ? '다운로드 중…' : 'Downloading…';
  static String updateCheckFailed(Object e) =>
      ko ? '업데이트 확인 실패: $e' : 'Update check failed: $e';
  static String downloadFailed(Object e) =>
      ko ? '다운로드 실패: $e' : 'Download failed: $e';
}
