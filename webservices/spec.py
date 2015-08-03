import copy

from smore.apispec import APISpec

from webservices import docs
from webservices import __API_VERSION__


spec = APISpec(
    title='OpenFEC',
    version=__API_VERSION__,
    info={'description': docs.DESCRIPTION},
    basePath='/v1',
    produces=['application/json'],
    plugins=['smore.ext.marshmallow'],
    securityDefinitions={
        'apiKey': {
            'type': 'apiKey',
            'name': 'api_key',
            'in': 'query',
        },
    },
    security=[{'apiKey': []}],
    tags=[
        {
            'name': 'candidate',
            'description': docs.CANDIDATE_TAG,
        },
        {
            'name': 'committee',
            'description': docs.COMMITTEE_TAG,
        },
        {
            'name': 'financial',
            'description': docs.FINANCIAL_TAG,
        },
        {
            'name': 'search',
            'description': docs.SEARCH_TAG,
        },
        {
            'name': 'filings',
            'description': docs.FILINGS,
        },
        {
            'name': 'schedules/schedule_a',
            'description': docs.SCHEDULE_A_TAG,
        },
        {
            'name': 'schedules/schedule_b',
            'description': docs.SCHEDULE_B_TAG,
        },
    ]
)


def doc(**kwargs):
    def wrapper(func):
        func.__apidoc__ = copy.deepcopy(getattr(func, '__apidoc__', {}))
        func.__apidoc__.update(kwargs)
        return func
    return wrapper
