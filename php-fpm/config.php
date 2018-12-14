<?php
return [
    'debug' => false,
    'mode' => 'development',
    'save.handler' => 'mongodb',
    'db.host' => 'mongodb://quantimodo:PxS5eX8AlhSG@169.61.123.138:27017/admin',
    'db.db' => 'xhprof',
    'db.options' => [],
    'templates.path' => dirname(__DIR__) . '/src/templates',
    'date.format' => 'M jS H:i:s',
    'detail.count' => 6,
    'page.limit' => 25,
    'profiler.enable' => function() {
        $url = $_SERVER['REQUEST_URI'];
        if (strpos($url, '/xhgui/') === 0) {return false;}
        $profilesPer100 = 100;
        if(getenv('XHGUI_PROFILES_PER_100')){
            $profilesPer100 = (int)getenv('XHGUI_PROFILES_PER_100');
        }
        $rand = random_int(1, 100);
        return $rand <= $profilesPer100;
    },
    'profiler.simple_url' => function($url) {
        $url = str_replace(array(
            'phpunit.php --configuration /vagrant/',
            '.quantimo.do',
            '/api/'
        ), '', $url);
        return preg_replace('/\=\d+/', '', $url);
    },
    'profiler.options' => [
        'ignored_functions' => ['call_user_func', 'call_user_func_array']
    ],
];