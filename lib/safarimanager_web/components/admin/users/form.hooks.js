let SelectSearch = {
    mounted() {
        console.log('mounted');

        var hiddenInput = document.getElementById('entity_organization_id'),
            input = document.getElementById('entity_organization_id_select'),
            list = input.getAttribute('list'),
            options = document.querySelectorAll('#' + list + ' option[data-value="' + hiddenInput.value + '"]');

        if (options.length > 0) {
            hiddenInput.value = options[0].dataset.value;
            input.value = options[0].value;
        }


        document.querySelector('#entity_organization_id_select').addEventListener('input', function (e) {
            var input = e.target,
                list = input.getAttribute('list'),
                options = document.querySelectorAll('#' + list + ' option[value="' + input.value + '"]'),
                hiddenInput = document.getElementById('entity_organization_id');

            if (options.length > 0) {
                hiddenInput.value = options[0].dataset.value;
                input.className = input.className + ' input-success'
            }
        });

        this.handleEvent('reset_entity_organization_id', ({ }) => {
            document.getElementById('entity_organization_id_select').value = '';
            document.getElementById('entity_organization_id').value = '';
            input.className = input.className.replace('input-success', '');
        });
    },
    beforeUpdate() {
        console.log('beforeUpdate');
    },
    updated() {
        console.log('updated');
    },
    destroyed() {
        console.log('destroyed');
    },
    disconnected() { console.log('disconnected'); },
    reconnected() { console.log('reconnected'); }
}

export { SelectSearch }
