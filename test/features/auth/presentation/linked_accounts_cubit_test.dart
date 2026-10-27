import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/auth/domain/entities/linked_accounts.dart';
import 'package:prachaya_run/features/auth/presentation/bloc/linked_accounts_cubit.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeAccountLinks links;
  late FakeBrowser browser;

  setUp(() {
    links = FakeAccountLinks();
    browser = FakeBrowser();
  });

  test('without a repository nothing shows', () async {
    final cubit = LinkedAccountsCubit(null, null);
    await cubit.load();
    expect(cubit.state.providers, isEmpty);
  });

  test('lists what the server offers; linking opens the browser', () async {
    final cubit = LinkedAccountsCubit(links, browser);
    await cubit.load();
    expect(cubit.state.providers, [LinkProvider.polar]);
    await cubit.link(LinkProvider.polar);
    expect(browser.opened.single.host, 'flow.polar.com');
    expect(cubit.state.busy, isNull);
    expect(cubit.state.failed, isFalse);
  });

  test('a server that cannot link says so', () async {
    links.unavailable = true;
    final cubit = LinkedAccountsCubit(links, browser);
    await cubit.load();
    await cubit.link(LinkProvider.polar);
    expect(cubit.state.failed, isTrue);
    expect(browser.opened, isEmpty);
  });

  test('refresh asks the server to look for workouts of ok links only, and '
      'unlink removes the link', () async {
    links.links.addAll([
      AccountLink(
        provider: LinkProvider.polar,
        status: LinkStatus.ok,
        linkedAt: t0,
      ),
      AccountLink(
        provider: LinkProvider.garmin,
        status: LinkStatus.expired,
        linkedAt: t0,
      ),
    ]);
    final cubit = LinkedAccountsCubit(links, browser);
    await cubit.refresh();
    expect(links.synced, [LinkProvider.polar]);
    // Still linked to Garmin though the server stopped offering it.
    expect(cubit.state.providers, [LinkProvider.polar, LinkProvider.garmin]);

    await cubit.unlink(LinkProvider.polar);
    expect(cubit.state.accounts.linkOf(LinkProvider.polar), isNull);
  });
}
