from __future__ import absolute_import
from optparse import make_option

from django.conf import settings
from django.core.management.base import BaseCommand
from zerver.lib.actions import do_create_realm, set_default_streams,\
    log_event, create_stream_if_needed, internal_prep_message, \
    do_create_stream
from zerver.models import Realm, get_realm, email_to_username, Stream
from zerver.lib.create_user import create_user
from zerver.lib.initial_password import initial_password

if not settings.VOYAGER:
    from zilencer.models import Deployment

import re
import sys

class Command(BaseCommand):
    help = """Create main realm and bots.

Usage: python manage.py initialize_bots --name='Foo, Inc.'"""
    option_list = BaseCommand.option_list + (
        make_option('-n', '--name',
                    dest='name',
                    type='str',
                    help='The user-visible name for the realm.'),
        )

    def handle(self, *args, **options):
        if options["name"] is None:
            print >>sys.stderr, "\033[1;31mPlease provide a name.\033[0m\n"
            self.print_help("python manage.py", "initialize_bots")
            exit(1)        

        domain = settings.ADMIN_DOMAIN
        name = options["name"]
        realm = get_realm(domain)
        created = not realm        
        if not realm:
            # We Create ADMIN Realm.
            realm = Realm(domain=domain, name=name,
                          restricted_to_domain=True)
            realm.save()
            print >>sys.stderr, "\033[1;31mCreated Admin Realm.\033[0m\n"

        admin_user = create_user("admin@domain.com", initial_password("admin@domain.com"), 
                                 realm, "admin",
                                 email_to_username("admin@domain.com"))

        create_user(settings.NOTIFICATION_BOT, initial_password(settings.NOTIFICATION_BOT), 
                    realm, "Notification Bot",
                    email_to_username(settings.NOTIFICATION_BOT), 
                    bot=True, bot_owner=admin_user)
        print >>sys.stderr, "\033[1;31mCreated Notification BOT.\033[0m\n"

        create_user(settings.NEW_USER_BOT, initial_password(settings.NEW_USER_BOT), 
                    realm, "New User Bot",
                    email_to_username(settings.NEW_USER_BOT), 
                    bot=True, bot_owner=admin_user)
        print >>sys.stderr, "\033[1;31mCreated New User BOT.\033[0m\n"

        create_user(settings.ERROR_BOT, initial_password(settings.ERROR_BOT), 
                    realm, "Error Bot",
                    email_to_username(settings.ERROR_BOT), 
                    bot=True, bot_owner=admin_user)
        print >>sys.stderr, "\033[1;31mCreated New User BOT.\033[0m\n"

        # Create streams for notifications and more
        encoding = sys.getfilesystemencoding()
        stream = Stream()
        stream.realm = realm
        stream.name = 'signups'.decode(encoding)
        stream.save()
